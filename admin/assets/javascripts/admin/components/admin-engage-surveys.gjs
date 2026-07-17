import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { Input } from "@ember/component";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminEngageSurveyTest from "./modal/admin-engage-survey-test";

const EMPTY_FORM = () => ({
  id: null,
  title: "",
  status: "draft",
  priority: 0,
  start_at: "",
  end_at: "",
  rules_json: "{}",
  survey_json: "{}",
});

export default class AdminEngageSurveys extends Component {
  @service modal;
  @service toasts;

  @tracked loading = false;
  @tracked surveys = [];
  @tracked form = EMPTY_FORM();

  constructor() {
    super(...arguments);
    this.load();
  }

  get hasSurveys() {
    return this.surveys.length > 0;
  }

  @action
  async load() {
    this.loading = true;
    try {
      const result = await ajax("/admin/plugins/discourse-engage/api/surveys");
      this.surveys = result.surveys || [];
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  resetForm() {
    this.form = EMPTY_FORM();
  }

  @action
  editSurvey(survey) {
    this.form = {
      id: survey.id,
      title: survey.title || "",
      status: survey.status || "draft",
      priority: survey.priority || 0,
      start_at: survey.start_at || "",
      end_at: survey.end_at || "",
      rules_json: JSON.stringify(survey.rules || {}, null, 2),
      survey_json: JSON.stringify(survey.survey_json || {}, null, 2),
    };
  }

  @action
  updateField(name, event) {
    this.form = { ...this.form, [name]: event.target.value };
  }

  @action
  async save() {
    const surveyBlob = {
      title: this.form.title,
      status: this.form.status,
      priority: Number(this.form.priority || 0),
      start_at: this.form.start_at || null,
      end_at: this.form.end_at || null,
      rules_json: this.form.rules_json || "{}",
      survey_json: this.form.survey_json || "{}",
    };

    const url = this.form.id
      ? `/admin/plugins/discourse-engage/api/surveys/${this.form.id}`
      : "/admin/plugins/discourse-engage/api/surveys";
    const type = this.form.id ? "PUT" : "POST";

    try {
      await ajax(url, { type, data: { survey_blob: JSON.stringify(surveyBlob) } });
      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_engage.admin.save") },
      });
      this.resetForm();
      await this.load();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async remove(id) {
    try {
      await ajax(`/admin/plugins/discourse-engage/api/surveys/${id}`, {
        type: "DELETE",
      });
      if (this.form.id === id) {
        this.resetForm();
      }
      await this.load();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  testSurvey(survey) {
    this.modal.show(AdminEngageSurveyTest, {
      model: survey,
    });
  }

  <template>
    <DPageSubheader @titleLabel={{i18n "discourse_engage.admin.heading"}}>
      <:actions as |actions|>
        <actions.Primary @label="discourse_engage.admin.new" @action={{this.resetForm}} />
        <actions.Default @label="discourse_engage.admin.refresh" @action={{this.load}} />
      </:actions>
    </DPageSubheader>

    <div class="engage-admin-layout">
      <div class="engage-admin-list">
        {{#if this.hasSurveys}}
          {{#each this.surveys as |survey|}}
            <div class="engage-admin-item">
              <div>
                <div><strong>{{survey.title}}</strong></div>
                <div>{{survey.status}} - priority {{survey.priority}}</div>
              </div>
              <div>
                <DButton @label="discourse_engage.admin.edit" @action={{fn this.editSurvey survey}} class="btn-small" />
                <DButton @label="discourse_engage.admin.test" @action={{fn this.testSurvey survey}} class="btn-small" />
                <DButton @label="discourse_engage.admin.delete" @action={{fn this.remove survey.id}} class="btn-danger btn-small" />
              </div>
            </div>
          {{/each}}
        {{else}}
          <div class="engage-admin-item">{{i18n "discourse_engage.admin.empty"}}</div>
        {{/if}}
      </div>

      <div class="engage-admin-form">
        <div class="control-group">
          <label>{{i18n "discourse_engage.admin.fields.title"}}</label>
          <Input @value={{this.form.title}} {{on "input" (fn this.updateField "title")}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_engage.admin.fields.status"}}</label>
          <select class="form-control" value={{this.form.status}} {{on "change" (fn this.updateField "status")}}>
            <option value="draft">{{i18n "discourse_engage.admin.status.draft"}}</option>
            <option value="active">{{i18n "discourse_engage.admin.status.active"}}</option>
            <option value="archived">{{i18n "discourse_engage.admin.status.archived"}}</option>
          </select>
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_engage.admin.fields.priority"}}</label>
          <Input @type="number" @value={{this.form.priority}} {{on "input" (fn this.updateField "priority")}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_engage.admin.fields.start_at"}}</label>
          <Input @value={{this.form.start_at}} {{on "input" (fn this.updateField "start_at")}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_engage.admin.fields.end_at"}}</label>
          <Input @value={{this.form.end_at}} {{on "input" (fn this.updateField "end_at")}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_engage.admin.fields.rules_json"}}</label>
          <textarea class="form-control" value={{this.form.rules_json}} {{on "input" (fn this.updateField "rules_json")}}></textarea>
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_engage.admin.fields.survey_json"}}</label>
          <textarea class="form-control" value={{this.form.survey_json}} {{on "input" (fn this.updateField "survey_json")}}></textarea>
        </div>

        <div class="control-group">
          <DButton @label="discourse_engage.admin.save" @action={{this.save}} class="btn-primary" />
          <DButton @label="discourse_engage.admin.cancel" @action={{this.resetForm}} class="btn-flat" />
        </div>
      </div>
    </div>
  </template>
}
