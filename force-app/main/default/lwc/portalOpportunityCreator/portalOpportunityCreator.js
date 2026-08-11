import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OpportunityCreator extends LightningElement {
    handleSuccess(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: `Opportunity created successfully: ${event.detail.id}`,
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Opportunity Creation Failed',
                message: event.detail.message,
                variant: 'error'
            })
        );
    }
}