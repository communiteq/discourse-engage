import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminEngageSurveyEdit extends Component {
  @service router;

  @tracked title = "";
  @tracked priority = 0;
  @tracked status = "draft";
  @tracked allowDecline = true;
  @tracked allowDefer = true;
  @tracked rulesJson = "{}";
  @tracked surveyJson = "{}";
  @tracked saving = false;

  loadedSurveySignature = null;

  get isNew() {
    return !this.args.survey?.id;
  }

  get pageTitle() {
    return this.isNew ? "New Survey" : `Edit: ${this.title}`;
  }

  get surveySignature() {
    const survey = this.args.survey || {};
    return [survey.id || "new", survey.updated_at || "", survey.status || "draft"].join(":");
  }

  get isDraftStatus() {
    return this.status === "draft";
  }

  get isActiveStatus() {
    return this.status === "active";
  }

  get isArchivedStatus() {
    return this.status === "archived";
  }

  @action
  async save() {
    this.saving = true;

    try {
      const payload = {
        survey_blob: {
          title: this.title,
          priority: this.priority,
          status: this.status,
          allow_decline: this.allowDecline,
          allow_defer: this.allowDefer,
          survey_json: this.surveyJson,
          rules_json: this.rulesJson,
        },
      };

      const url = this.isNew
        ? "/admin/plugins/discourse-engage/api/surveys"
        : `/admin/plugins/discourse-engage/api/surveys/${this.args.survey.id}`;

      const method = this.isNew ? "post" : "put";

      await ajax(url, {
        type: method,
        data: JSON.stringify(payload),
        contentType: "application/json",
      });

      this.router.transitionTo("adminPlugins.show.discourse-engage-surveys");
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  cancel() {
    this.router.transitionTo("adminPlugins.show.discourse-engage-surveys");
  }

  @action
  syncFromSurvey() {
    if (this.loadedSurveySignature === this.surveySignature) {
      return;
    }

    const survey = this.args.survey || {};

    this.title = survey.title || "";
    this.priority = survey.priority || 0;
    this.status = survey.status || "draft";
    this.allowDecline = survey.allow_decline ?? true;
    this.allowDefer = survey.allow_defer ?? true;
    this.rulesJson = this.stringifyJson(survey.rules_json ?? survey.rules ?? {});
    this.surveyJson = this.stringifyJson(survey.survey_json ?? {});
    this.loadedSurveySignature = this.surveySignature;
  }

  stringifyJson(value) {
    if (typeof value === "string") {
      return value;
    }

    return JSON.stringify(value || {}, null, 2);
  }

  <template>
    <div
      class="engage-survey-edit"
      {{didInsert this.syncFromSurvey}}
      {{didUpdate this.syncFromSurvey @survey}}
    >
      <h2>{{this.pageTitle}}</h2>

      <form>
        <div class="form-group">
          <label for="survey-title">{{i18n "discourse_engage.admin.fields.title"}}</label>
          <input
            id="survey-title"
            type="text"
            value={{this.title}}
            {{on "input" this.setTitle}}
            class="form-control"
          />
        </div>

        <div class="form-group">
          <label for="survey-priority">{{i18n "discourse_engage.admin.fields.priority"}}</label>
          <input
            id="survey-priority"
            type="number"
            value={{this.priority}}
            {{on "input" this.setPriority}}
            class="form-control"
          />
        </div>

        <div class="form-group">
          <label for="survey-status">{{i18n "discourse_engage.admin.fields.status"}}</label>
          <select
            id="survey-status"
            {{on "change" this.setStatus}}
            class="form-control"
          >
            <option value="draft" selected={{this.isDraftStatus}}>{{i18n "discourse_engage.admin.status.draft"}}</option>
            <option value="active" selected={{this.isActiveStatus}}>{{i18n "discourse_engage.admin.status.active"}}</option>
            <option value="archived" selected={{this.isArchivedStatus}}>{{i18n "discourse_engage.admin.status.archived"}}</option>
          </select>
        </div>

        <div class="form-group">
          <label>
            <input
              type="checkbox"
              checked={{this.allowDecline}}
              {{on "change" this.setAllowDecline}}
            />
            {{i18n "discourse_engage.admin.fields.allow_decline"}}
          </label>
        </div>

        <div class="form-group">
          <label>
            <input
              type="checkbox"
              checked={{this.allowDefer}}
              {{on "change" this.setAllowDefer}}
            />
            {{i18n "discourse_engage.admin.fields.allow_defer"}}
          </label>
        </div>

        <div class="form-group">
          <label for="survey-rules">{{i18n "discourse_engage.admin.fields.rules_json"}}</label>
          <textarea
            id="survey-rules"
            value={{this.rulesJson}}
            {{on "input" this.setRulesJson}}
            class="form-control"
            rows="6"
          ></textarea>
          <p class="form-help">{{i18n "discourse_engage.admin.fields.rules_json_help"}}</p>
        </div>

        <div class="form-group">
          <label for="survey-json">{{i18n "discourse_engage.admin.fields.survey_json"}}</label>
          <textarea
            id="survey-json"
            value={{this.surveyJson}}
            {{on "input" this.setSurveyJson}}
            class="form-control"
            rows="10"
          ></textarea>
        </div>

        <div class="form-group">
          <DButton
            @label="discourse_engage.admin.save"
            @action={{this.save}}
            @loading={{this.saving}}
            class="btn-primary"
          />
          <DButton
            @label="discourse_engage.admin.cancel"
            @action={{this.cancel}}
            class="btn-default"
          />
        </div>
      </form>
    </div>
  </template>

  @action
  setTitle(event) {
    this.title = event.target.value;
  }

  @action
  setPriority(event) {
    this.priority = parseInt(event.target.value, 10);
  }

  @action
  setStatus(event) {
    this.status = event.target.value;
  }

  @action
  setAllowDecline(event) {
    this.allowDecline = event.target.checked;
  }

  @action
  setAllowDefer(event) {
    this.allowDefer = event.target.checked;
  }

  @action
  setRulesJson(event) {
    this.rulesJson = event.target.value;
  }

  @action
  setSurveyJson(event) {
    this.surveyJson = event.target.value;
  }
}
