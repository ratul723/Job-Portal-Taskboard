import { LightningElement, wire } from 'lwc';

import getTasks from '@salesforce/apex/JiraTaskController.getTasks';
import getLastSynced from '@salesforce/apex/JiraTaskController.getLastSynced';
import syncTasks from '@salesforce/apex/JiraTaskController.syncTasks';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { refreshApex } from '@salesforce/apex';

export default class JiraTaskBoard extends LightningElement {

    tasks = [];

    lastSynced;

    selectedTask;

    isLoading = false;

    errorMessage;

    recordType = 'Account';

    createdAccountId;

    wiredTasksResult;

    wiredLastSyncedResult;

    recordTypeOptions = [
        {
            label: 'Account',
            value: 'Account'
        },
        {
            label: 'Account + Opportunity',
            value: 'AccountOpportunity'
        },
        {
            label: 'Contact',
            value: 'Contact'
        }
    ];

    @wire(getTasks)
    wiredTasks(result) {

        this.wiredTasksResult = result;

        if (result.data) {

            this.tasks = result.data;

            this.errorMessage = undefined;

        } else if (result.error) {

            this.errorMessage =
                this.reduceError(result.error);
        }
    }

    @wire(getLastSynced)
    wiredLastSynced(result) {

        this.wiredLastSyncedResult = result;

        if (result.data) {
            this.lastSynced = result.data;
        }
    }

    get todoTasks() {

        return this.tasks.filter(
            task =>
                task.Status_Category__c === 'new'
        );
    }

    get inProgressTasks() {

        return this.tasks.filter(
            task =>
                task.Status_Category__c === 'indeterminate'
        );
    }

    get doneTasks() {

        return this.tasks.filter(
            task =>
                task.Status_Category__c === 'done'
        );
    }

    get showAccountForm() {

        return (
            this.recordType === 'Account' ||
            this.recordType === 'AccountOpportunity'
        );
    }

    get showOpportunityForm() {

        return (
            this.recordType === 'AccountOpportunity' &&
            this.createdAccountId
        );
    }

    get showContactForm() {

        return this.recordType === 'Contact';
    }

    get disableOpportunityForm() {

        return !this.createdAccountId;
    }

    get accountName() {

        if (!this.selectedTask) {
            return '';
        }

        return this.selectedTask.Summary__c;
    }

    get opportunityName() {

        if (!this.selectedTask) {
            return '';
        }

        return this.selectedTask.Summary__c;
    }

    get contactLastName() {

        if (!this.selectedTask) {
            return '';
        }

        return this.selectedTask.Summary__c;
    }

    get opportunityStage() {

        if (!this.selectedTask) {
            return 'Prospecting';
        }

        const category =
            this.selectedTask.Status_Category__c;

        if (category === 'done') {
            return 'Closed Won';
        }

        if (category === 'indeterminate') {
            return 'Qualification';
        }

        return 'Prospecting';
    }

    handleRefresh() {

        this.isLoading = true;

        Promise.all([
            refreshApex(this.wiredTasksResult),
            refreshApex(this.wiredLastSyncedResult)
        ])
            .catch(error => {

                this.errorMessage =
                    this.reduceError(error);

            })
            .finally(() => {

                this.isLoading = false;
            });
    }

    handleSync() {

        this.isLoading = true;

        this.errorMessage = undefined;

        syncTasks()
            .then(result => {

                if (result.success) {

                    this.showToast(
                        'Sync Complete',
                        result.message,
                        'success'
                    );

                    return Promise.all([
                        refreshApex(this.wiredTasksResult),
                        refreshApex(this.wiredLastSyncedResult)
                    ]);

                }

                this.errorMessage =
                    result.message;

                this.showToast(
                    'Sync Failed',
                    result.message,
                    'error'
                );

                return undefined;
            })
            .catch(error => {

                this.errorMessage =
                    this.reduceError(error);

                this.showToast(
                    'Unexpected Error',
                    this.errorMessage,
                    'error'
                );
            })
            .finally(() => {

                this.isLoading = false;
            });
    }

    handleTaskClick(event) {

        const taskId =
            event.currentTarget.dataset.id;

        this.selectedTask =
            this.tasks.find(
                task => task.Id === taskId
            );

        this.createdAccountId = undefined;

        this.recordType = 'Account';
    }

    closeModal() {

        this.selectedTask = undefined;

        this.createdAccountId = undefined;
    }

    handleRecordTypeChange(event) {

        this.recordType =
            event.detail.value;

        this.createdAccountId =
            undefined;
    }

    handleAccountSuccess(event) {

        this.createdAccountId =
            event.detail.id;

        this.showToast(
            'Account Created',
            'The Salesforce Account was created successfully.',
            'success'
        );

        if (this.recordType === 'Account') {

            this.closeModal();
        }
    }

    handleOpportunitySuccess() {

        this.showToast(
            'Opportunity Created',
            'The Salesforce Opportunity was created successfully.',
            'success'
        );

        this.closeModal();
    }

    handleContactSuccess() {

        this.showToast(
            'Contact Created',
            'The Salesforce Contact was created successfully.',
            'success'
        );

        this.closeModal();
    }

    handleFormError(event) {

        this.showToast(
            'Record Creation Failed',
            event.detail.message,
            'error'
        );
    }

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceError(error) {

        if (!error) {
            return 'Unknown error.';
        }

        if (Array.isArray(error.body)) {

            return error.body
                .map(item => item.message)
                .join(', ');
        }

        if (error.body?.message) {

            return error.body.message;
        }

        if (error.message) {

            return error.message;
        }

        return 'An unexpected error occurred.';
    }
}