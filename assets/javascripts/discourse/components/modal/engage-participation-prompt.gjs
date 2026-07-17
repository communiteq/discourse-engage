import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import EngageSurveyModal from "discourse/plugins/discourse-engage/discourse/components/modal/engage-survey-modal";

export default class EngageParticipationPrompt extends Component {
  @service modal;

  @action
  async choose(decision) {
    try {
      await ajax(`/discourse-engage/surveys/${this.args.model.id}/decision`, {
        type: "POST",
        data: { decision },
      });

      this.args.closeModal();

      if (decision === "start") {
        this.modal.show(EngageSurveyModal, { model: this.args.model });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_engage.prompt.title" title=@model.title}}
      @closeModal={{@closeModal}}
      class="engage-prompt-modal"
    >
      <:body>
        <div class="engage-prompt-body">
          <p>{{i18n "discourse_engage.prompt.body"}}</p>
          <DButton
            @label="discourse_engage.prompt.yes_now"
            class="btn-primary"
            @action={{fn this.choose "start"}}
          />
          <DButton
            @label="discourse_engage.prompt.ask_tomorrow"
            class="btn-default"
            @action={{fn this.choose "defer"}}
          />
          <DButton
            @label="discourse_engage.prompt.no_thanks"
            class="btn-flat"
            @action={{fn this.choose "decline"}}
          />
        </div>
      </:body>
    </DModal>
  </template>
}
