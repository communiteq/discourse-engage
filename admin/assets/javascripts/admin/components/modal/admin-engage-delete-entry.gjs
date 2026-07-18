import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import DModal from "discourse/components/d-modal";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class AdminEngageDeleteEntry extends Component {
  @tracked resetEligibility = false;
  @tracked deleting = false;

  @action
  toggleReset(event) {
    this.resetEligibility = event.target.checked;
  }

  @action
  async confirm() {
    this.deleting = true;
    try {
      await this.args.model.onConfirm(this.resetEligibility);
      this.args.closeModal();
    } finally {
      this.deleting = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_engage.admin.delete_entry_modal.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <p>{{i18n "discourse_engage.admin.delete_entry_modal.body"
            username=@model.entry.username}}</p>

        <div class="engage-delete-entry-reset">
          <label class="engage-delete-entry-reset__label">
            <input
              type="checkbox"
              checked={{this.resetEligibility}}
              {{on "change" this.toggleReset}}
            />
            {{i18n "discourse_engage.admin.delete_entry_modal.reset_label"}}
          </label>
          <p class="engage-delete-entry-reset__hint">
            {{#if this.resetEligibility}}
              {{i18n "discourse_engage.admin.delete_entry_modal.reset_hint_on"}}
            {{else}}
              {{i18n "discourse_engage.admin.delete_entry_modal.reset_hint_off"}}
            {{/if}}
          </p>
        </div>
      </:body>
      <:footer>
        <DButton
          @label="discourse_engage.admin.delete_entry_modal.confirm"
          @action={{this.confirm}}
          @loading={{this.deleting}}
          class="btn-danger"
        />
        <DButton
          @label="cancel"
          @action={{@closeModal}}
          class="btn-default"
        />
      </:footer>
    </DModal>
  </template>
}
