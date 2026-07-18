import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class EngageSurveyModal extends Component {
  @tracked surveyModel = null;
  @tracked done = false;

  @action
  setupSurvey(element) {
    const config = this.args.model?.survey_json;
    const SurveyCtor = window.Survey?.Model;

    if (!config || !SurveyCtor) {
      return;
    }

    const surveyModel = new SurveyCtor(config);
    surveyModel.onComplete.add((sender) => {
      this.submit(sender.data);
    });

    this.surveyModel = surveyModel;

    if (window.Survey?.SurveyNG?.render) {
      window.Survey.SurveyNG.render(element, { model: surveyModel });
    } else if (window.SurveyUI?.renderSurvey) {
      window.SurveyUI.renderSurvey(surveyModel, element);
    } else if (window.jQuery?.fn?.Survey) {
      window.jQuery(element).Survey({ model: surveyModel });
    }
  }

  @action
  async submit(answers) {
    try {
      await ajax(`/discourse-engage/surveys/${this.args.model.id}/responses`, {
        type: "POST",
        data: {
          answers,
          metadata: {
            user_agent: navigator.userAgent,
            locale: document.documentElement.lang,
          },
        },
      });
      this.done = true;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      class="engage-survey-modal"
    >
      <:body>
        {{#if this.done}}
          <p>{{i18n "discourse_engage.survey.thanks"}}</p>
        {{else}}
          <div class="engage-survey-host" {{didInsert this.setupSurvey}}></div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
