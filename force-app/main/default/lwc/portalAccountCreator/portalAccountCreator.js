import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AccountCreator extends LightningElement {
    handleSuccess(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: `Account created successfully: ${event.detail.id}`,
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Account Creation Failed',
                message: event.detail.message,
                variant: 'error'
            })
        );
    }
}