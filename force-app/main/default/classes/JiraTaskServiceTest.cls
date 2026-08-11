@IsTest
private class JiraTaskServiceTest {

    private class JiraSuccessMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest request
        ) {

            System.assertEquals(
                'GET',
                request.getMethod()
            );

            System.assert(
                request.getEndpoint().contains(
                    'callout:Jira_API'
                )
            );

            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(200);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                '{' +
                    '"issues":[' +
                        '{' +
                            '"id":"10001",' +
                            '"key":"SID-1",' +
                            '"fields":{' +
                                '"summary":"Set up new client",' +
                                '"status":{' +
                                    '"name":"To Do",' +
                                    '"statusCategory":{' +
                                        '"key":"new",' +
                                        '"name":"To Do"' +
                                    '}' +
                                '},' +
                                '"assignee":{' +
                                    '"displayName":"John Doe",' +
                                    '"emailAddress":"john@example.com"' +
                                '},' +
                                '"priority":{' +
                                    '"name":"High"' +
                                '}' +
                            '}' +
                        '},' +
                        '{' +
                            '"id":"10002",' +
                            '"key":"SID-2",' +
                            '"fields":{' +
                                '"summary":"Prepare documentation",' +
                                '"status":{' +
                                    '"name":"In Progress",' +
                                    '"statusCategory":{' +
                                        '"key":"indeterminate",' +
                                        '"name":"In Progress"' +
                                    '}' +
                                '},' +
                                '"assignee":null,' +
                                '"priority":{' +
                                    '"name":"Medium"' +
                                '}' +
                            '}' +
                        '},' +
                        '{' +
                            '"id":"10003",' +
                            '"key":"SID-3",' +
                            '"fields":{' +
                                '"summary":"Complete onboarding",' +
                                '"status":{' +
                                    '"name":"Done",' +
                                    '"statusCategory":{' +
                                        '"key":"done",' +
                                        '"name":"Done"' +
                                    '}' +
                                '},' +
                                '"assignee":{' +
                                    '"displayName":"Jane Doe"' +
                                '},' +
                                '"priority":{' +
                                    '"name":"Low"' +
                                '}' +
                            '}' +
                        '}' +
                    ']' +
                '}'
            );

            return response;
        }
    }

    private class JiraErrorMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest request
        ) {

            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(500);

            response.setStatus(
                '500 Internal Server Error'
            );

            response.setBody(
                '{"error":"Internal Jira error"}'
            );

            return response;
        }
    }

    @IsTest
    static void testSuccessfulSync() {

        Test.setMock(
            HttpCalloutMock.class,
            new JiraSuccessMock()
        );

        Test.startTest();

        JiraTaskService.JiraSyncResult result =
            JiraTaskService.syncTasks();

        Test.stopTest();

        System.assertEquals(
            true,
            result.success
        );

        System.assertEquals(
            3,
            result.received
        );

        System.assertEquals(
            3,
            result.saved
        );

        List<Jira_Task__c> tasks = [
            SELECT
                Jira_Key__c,
                Summary__c,
                Status__c,
                Status_Category__c,
                Assignee__c,
                Priority__c,
                URL__c,
                Last_Synced__c
            FROM Jira_Task__c
        ];

        System.assertEquals(
            3,
            tasks.size()
        );

        System.assertEquals(
            'SID-1',
            tasks[0].Jira_Key__c
        );
    }

    @IsTest
    static void testUpsertDoesNotDuplicate() {

        Jira_Task__c existing =
            new Jira_Task__c(
                Jira_Key__c = 'SID-1',
                Summary__c = 'Old summary',
                Status__c = 'To Do'
            );

        insert existing;

        Test.setMock(
            HttpCalloutMock.class,
            new JiraSuccessMock()
        );

        Test.startTest();

        JiraTaskService.JiraSyncResult result =
            JiraTaskService.syncTasks();

        Test.stopTest();

        System.assertEquals(
            true,
            result.success
        );

        List<Jira_Task__c> tasks = [
            SELECT Id, Jira_Key__c
            FROM Jira_Task__c
            WHERE Jira_Key__c = 'SID-1'
        ];

        System.assertEquals(
            1,
            tasks.size()
        );
    }

    @IsTest
    static void testJiraServerError() {

        Test.setMock(
            HttpCalloutMock.class,
            new JiraErrorMock()
        );

        Test.startTest();

        JiraTaskService.JiraSyncResult result =
            JiraTaskService.syncTasks();

        Test.stopTest();

        System.assertEquals(
            false,
            result.success
        );

        System.assert(
            result.message.contains(
                'Jira returned HTTP 500'
            )
        );
    }

    @IsTest
    static void testControllerGetTasks() {

        insert new Jira_Task__c(
            Jira_Key__c = 'SID-10',
            Summary__c = 'Controller Test',
            Status__c = 'To Do',
            Status_Category__c = 'new',
            Assignee__c = 'Tester',
            Priority__c = 'Medium',
            URL__c = 'https://example.atlassian.net/browse/SID-10'
        );

        Test.startTest();

        List<Jira_Task__c> tasks =
            JiraTaskController.getTasks();

        Test.stopTest();

        System.assertEquals(
            1,
            tasks.size()
        );

        System.assertEquals(
            'SID-10',
            tasks[0].Jira_Key__c
        );
    }

    @IsTest
    static void testControllerGetLastSynced() {

        insert new Jira_Sync__c(
            Name = 'Default',
            Last_Synced__c = System.now()
        );

        Test.startTest();

        Datetime result =
            JiraTaskController.getLastSynced();

        Test.stopTest();

        System.assertNotEquals(
            null,
            result
        );
    }
}