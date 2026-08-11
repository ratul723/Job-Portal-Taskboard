public with sharing class JiraTaskService {

    public class JiraSyncResult {
        @AuraEnabled public Integer received;
        @AuraEnabled public Integer saved;
        @AuraEnabled public Datetime lastSynced;
        @AuraEnabled public String message;
        @AuraEnabled public Boolean success;

        public JiraSyncResult() {
            received = 0;
            saved = 0;
            lastSynced = null;
            message = '';
            success = false;
        }
    }

    public class JiraIntegrationException extends Exception {}

    private static final String NAMED_CREDENTIAL = 'Jira_API';
    private static final String JIRA_PROJECT_JQL = 'project = SFI ORDER BY created DESC';
    private static final Integer MAX_RESULTS = 50;
    private static final Integer TIMEOUT_MS = 20000;

    public static JiraSyncResult syncTasks() {

        JiraSyncResult result = new JiraSyncResult();

        HttpRequest request = new HttpRequest();

        String encodedJql = EncodingUtil.urlEncode(
            JIRA_PROJECT_JQL,
            'UTF-8'
        );

        String endpoint =
            'callout:' +
            NAMED_CREDENTIAL +
            '/rest/api/3/search/jql' +
            '?jql=' +
            encodedJql +
            '&maxResults=' +
            String.valueOf(MAX_RESULTS) +
            '&fields=summary,status,assignee,priority';

        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MS);

        Http http = new Http();

        HttpResponse response;

        try {
            response = http.send(request);
        } catch (System.CalloutException ex) {
            saveSyncError(
                'Jira callout failed: ' + ex.getMessage()
            );

            result.message =
                'Unable to contact Jira. Please try again.';
            return result;       
         }

        if (response.getStatusCode() < 200 ||
            response.getStatusCode() >= 300) {

                String responseBody = response.getBody();

                    String errorMessage =
                        'Jira returned HTTP ' +
                        response.getStatusCode() +
                        ': ' +
                        response.getStatus();

                    if (!String.isBlank(responseBody)) {
                        errorMessage +=
                            ' | Jira response: ' +
                            responseBody;
                    }

                    System.debug(
                        LoggingLevel.ERROR,
                        'Jira HTTP Error: ' + errorMessage
                    );

                    saveSyncError(errorMessage);

                    result.message = errorMessage;
                    return result;
        }

        List<JiraIssue> issues;

        try {
            JiraSearchResponse jiraResponse =
                (JiraSearchResponse) JSON.deserialize(
                    response.getBody(),
                    JiraSearchResponse.class
                );

            issues =
                jiraResponse != null && jiraResponse.issues != null
                    ? jiraResponse.issues
                    : new List<JiraIssue>();

        } catch (Exception ex) {

            saveSyncError(
                'Invalid Jira JSON response: ' +
                ex.getMessage()
            );

            result.message =
                'Jira returned an unexpected response.';
            return result;
        }

        result.received = issues.size();

        if (issues.isEmpty()) {

            Datetime syncTime = System.now();

            saveSyncSuccess(syncTime);

            result.lastSynced = syncTime;
            result.saved = 0;
            result.success = true;
            result.message = 'No Jira issues were returned.';

            return result;
        }

        List<Jira_Task__c> recordsToUpsert =
            new List<Jira_Task__c>();

        for (JiraIssue issue : issues) {

            if (issue == null || String.isBlank(issue.key)) {
                continue;
            }

            Jira_Task__c task = new Jira_Task__c();

            task.Jira_Key__c = issue.key;
            task.Jira_Id__c = issue.id;

            if (issue.fields != null) {

                task.Summary__c =
                    issue.fields.summary;

                if (issue.fields.status != null) {

                    task.Status__c =
                        issue.fields.status.name;

                    if (issue.fields.status.statusCategory != null) {

                        task.Status_Category__c =
                            issue.fields.status.statusCategory.key;
                    }
                }

                if (issue.fields.assignee != null) {

                    if (!String.isBlank(
                        issue.fields.assignee.displayName
                    )) {
                        task.Assignee__c =
                            issue.fields.assignee.displayName;
                    } else {
                        task.Assignee__c =
                            issue.fields.assignee.emailAddress;
                    }
                }

                if (issue.fields.priority != null) {

                    task.Priority__c =
                        issue.fields.priority.name;
                }
            }

            task.URL__c =
                buildIssueUrl(issue.key);

            task.Last_Synced__c =
                System.now();

            recordsToUpsert.add(task);
        }

        if (recordsToUpsert.isEmpty()) {

            Datetime syncTime = System.now();

            saveSyncSuccess(syncTime);

            result.lastSynced = syncTime;
            result.success = true;
            result.message =
                'Jira returned issues, but none contained valid keys.';

            return result;
        }

        try {

            Database.UpsertResult[] saveResults =
                Database.upsert(
                    recordsToUpsert,
                    Jira_Task__c.Fields.Jira_Key__c,
                    false
                );

            Integer successfulRecords = 0;
            List<String> errors = new List<String>();

            for (Database.UpsertResult saveResult :
                saveResults) {

                if (saveResult.isSuccess()) {

                    successfulRecords++;

                } else {

                    for (
                        Database.Error databaseError :
                        saveResult.getErrors()
                    ) {
                        errors.add(
                            databaseError.getStatusCode() +
                            ': ' +
                            databaseError.getMessage()
                        );
                    }
                }
            }

            result.saved = successfulRecords;

            if (!errors.isEmpty()) {

                saveSyncError(
                    'Some Jira records failed: ' +
                    String.join(errors, ' | ')
                );

                result.message =
                    'Sync completed with some record errors.';
                result.success = false;

            } else {

                Datetime syncTime = System.now();

                saveSyncSuccess(syncTime);

                result.lastSynced = syncTime;
                result.success = true;
                result.message =
                    'Jira synchronization completed successfully.';
            }

        } catch (DmlException ex) {

            saveSyncError(
                'Salesforce DML failed: ' +
                ex.getMessage()
            );

            result.message =
                'Salesforce could not save the Jira records.';
            result.success = false;
        }

        return result;
    }

    private static String buildIssueUrl(String issueKey) {

        String endpoint =
            System.Label.Jira_Base_URL;

        if (String.isBlank(endpoint)) {
            endpoint = 'https://YOUR-DOMAIN.atlassian.net';
        }

        return endpoint + '/browse/' + issueKey;
    }

    private static void saveSyncSuccess(Datetime syncTime) {

        Jira_Sync__c syncRecord =
            getOrCreateSyncRecord();

        syncRecord.Name = 'Default';
        syncRecord.Last_Synced__c = syncTime;
        syncRecord.Last_Error__c = null;

        update syncRecord;
    }

    private static void saveSyncError(String errorMessage) {

        try {

            Jira_Sync__c syncRecord =
                getOrCreateSyncRecord();

            syncRecord.Name = 'Default';
            syncRecord.Last_Error__c =
                truncate(errorMessage, 32000);

            update syncRecord;

        } catch (Exception ignored) {
            // Do not hide the original integration error.
        }
    }

    private static Jira_Sync__c getOrCreateSyncRecord() {

        List<Jira_Sync__c> records = [
            SELECT
                Id,
                Name,
                Last_Synced__c,
                Last_Error__c
            FROM Jira_Sync__c
            WHERE Name = 'Default'
            LIMIT 1
        ];

        if (!records.isEmpty()) {
            return records[0];
        }

        Jira_Sync__c newRecord =
            new Jira_Sync__c(
                Name = 'Default'
            );

        insert newRecord;

        return newRecord;
    }

    private static String truncate(
        String value,
        Integer maximumLength
    ) {

        if (value == null) {
            return null;
        }

        if (value.length() <= maximumLength) {
            return value;
        }

        return value.substring(0, maximumLength);
    }

    public class JiraSearchResponse {
        public List<JiraIssue> issues;
        public String nextPageToken;
        public Boolean isLast;
    }

    public class JiraIssue {
        public String id;
        public String key;
        public JiraFields fields;
    }

    public class JiraFields {
        public String summary;
        public JiraStatus status;
        public JiraUser assignee;
        public JiraPriority priority;
    }

    public class JiraStatus {
        public String name;
        public JiraStatusCategory statusCategory;
    }

    public class JiraStatusCategory {
        public String key;
        public String name;
    }

    public class JiraUser {
        public String displayName;
        public String emailAddress;
    }

    public class JiraPriority {
        public String name;
    }
}