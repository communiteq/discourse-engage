import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminEngageSurveyEdit extends Component {
  @service router;

  @tracked title = this.args.survey?.title || "";
  @tracked priority = this.args.survey?.priority || 0;
  @tracked status = this.args.survey?.status || "draft";
  @tracked allowDecline = this.args.survey?.allow_decline ?? true;
  @tracked allowDefer = this.args.survey?.allow_defer ?? true;
  @tracked rulesJson = JSON.stringify(
    this.args.survey?.rules_json || {},
    null,
    2
  );
  @tracked surveyJson = JSON.stringify(
    this.args.survey?.survey_json || {},
    null,
    2
  );
  @tracked saving = false;

  get isNew() {
    return !this.args.survey?.id;
  }

  get pageTitle() {
    return this.isNew ? "New Survey" : `Edit: ${this.title}`;
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

  <template>
    <div class="engage-survey-edit">
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
            value={{this.status}}
            {{on "change" this.setStatus}}
            class="form-control"
          >
            <option value="draft">{{i18n "discourse_engage.admin.status.draft"}}</option>
            <option value="active">{{i18n "discourse_engage.admin.status.active"}}</option>
            <option value="archived">{{i18n "discourse_engage.admin.status.archived"}}</option>
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
