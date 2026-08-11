public with sharing class JiraTaskController {

    @AuraEnabled
    public static JiraTaskService.JiraSyncResult syncTasks() {

        return JiraTaskService.syncTasks();
    }

    @AuraEnabled(cacheable=true)
    public static List<Jira_Task__c> getTasks() {

        return [
            SELECT
                Id,
                Name,
                Jira_Id__c,
                Jira_Key__c,
                Summary__c,
                Status__c,
                Status_Category__c,
                Assignee__c,
                Priority__c,
                URL__c,
                Last_Synced__c
            FROM Jira_Task__c
            ORDER BY Last_Synced__c DESC, Jira_Key__c ASC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Datetime getLastSynced() {

        List<Jira_Sync__c> syncRecords = [
            SELECT Last_Synced__c
            FROM Jira_Sync__c
            WHERE Name = 'Default'
            LIMIT 1
        ];

        if (syncRecords.isEmpty()) {
            return null;
        }

        return syncRecords[0].Last_Synced__c;
    }
}