import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminEngageSurveyTest from "./modal/admin-engage-survey-test";

export default class AdminEngageSurveys extends Component {
  @service modal;
  @service router;

  @tracked loading = false;
  @tracked surveys = [];

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
  testSurvey(survey) {
    this.modal.show(AdminEngageSurveyTest, {
      model: survey,
    });
  }

  @action
  newSurvey() {
    this.router.transitionTo(
      "adminPlugins.show.discourse-engage-surveys.edit",
      "new"
    );
  }

  <template>
    <DPageSubheader @titleLabel={{i18n "discourse_engage.admin.heading"}}>
      <:actions as |actions|>
        <actions.Primary @label="discourse_engage.admin.new" @action={{this.newSurvey}} />
        <actions.Default @label="discourse_engage.admin.refresh" @action={{this.load}} />
      </:actions>
    </DPageSubheader>

    <div class="engage-admin">
      {{#if this.hasSurveys}}
        <table class="engage-admin-table">
          <thead>
            <tr>
              <th>{{i18n "discourse_engage.admin.fields.title"}}</th>
              <th>{{i18n "discourse_engage.admin.fields.priority"}}</th>
              <th>{{i18n "discourse_engage.admin.fields.status"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each this.surveys as |survey|}}
              <tr>
                <td><strong>{{survey.title}}</strong></td>
                <td>{{survey.priority}}</td>
                <td>
                  <span class="engage-status-badge engage-status-{{survey.status}}">
                    {{i18n (concat "discourse_engage.admin.status." survey.status)}}
                  </span>
                </td>
                <td class="engage-admin-actions">
                  <LinkTo
                    @route="adminPlugins.show.discourse-engage-surveys.edit"
                    @model={{survey.id}}
                    class="btn btn-small"
                  >{{i18n "discourse_engage.admin.edit"}}</LinkTo>
                  <LinkTo
                    @route="adminPlugins.show.discourse-engage-surveys.entries"
                    @model={{survey.id}}
                    class="btn btn-small"
                  >{{i18n "discourse_engage.admin.entries"}}</LinkTo>
                  <DButton @label="discourse_engage.admin.test" @action={{fn this.testSurvey survey}} class="btn-small" />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <div class="engage-admin-empty">{{i18n "discourse_engage.admin.empty"}}</div>
      {{/if}}
    </div>
  </template>
}
