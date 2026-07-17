import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminEngageSurveyResponses extends Component {
  @tracked expandedRows = new Set();
  @tracked exporting = false;

  get hasEntries() {
    return this.args.entries?.length > 0;
  }

  @action
  toggleExpand(responseId) {
    if (this.expandedRows.has(responseId)) {
      this.expandedRows.delete(responseId);
    } else {
      this.expandedRows.add(responseId);
    }
    this.expandedRows = new Set(this.expandedRows);
  }

  @action
  async exportCsv() {
    this.exporting = true;

    try {
      const surveyId = this.args.survey.id;
      const url = `/admin/plugins/discourse-engage/api/surveys/${surveyId}/export`;

      const response = await fetch(url, {
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
        },
      });

      if (!response.ok) {
        throw new Error("Export failed");
      }

      const blob = await response.blob();
      const urlObj = window.URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = urlObj;
      link.download = `survey-${surveyId}-entries.csv`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(urlObj);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.exporting = false;
    }
  }

  <template>
    <div class="engage-survey-entries">
      <div class="entries-header">
        <h2>{{@survey.title}} - {{i18n "discourse_engage.admin.entries"}}</h2>
        <DButton
          @label="Export CSV"
          @action={{this.exportCsv}}
          @loading={{this.exporting}}
          class="btn-default"
        />
      </div>

      {{#if this.hasEntries}}
        <table class="engage-entries-table">
          <thead>
            <tr>
              <th>{{i18n "discourse_engage.admin.entries_table.username"}}</th>
              <th>{{i18n "discourse_engage.admin.entries_table.submitted_at"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @entries as |entry|}}
              <tr class="entry-row">
                <td>{{entry.username}}</td>
                <td>{{entry.submitted_at}}</td>
                <td class="entry-actions">
                  <button
                    {{on "click" (fn this.toggleExpand entry.response_id)}}
                    class="btn btn-small"
                  >
                    {{#if (this.expandedRows.has entry.response_id)}}
                      Hide Data
                    {{else}}
                      Show Data
                    {{/if}}
                  </button>
                </td>
              </tr>
              {{#if (this.expandedRows.has entry.response_id)}}
                <tr class="entry-expanded">
                  <td colspan="3">
                    <div class="entry-data">
                      <h4>Answers:</h4>
                      <pre>{{this.formatJson entry.answers}}</pre>
                    </div>
                  </td>
                </tr>
              {{/if}}
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="no-entries">{{i18n "discourse_engage.admin.no_entries"}}</p>
      {{/if}}
    </div>
  </template>

  @action
  formatJson(data) {
    return JSON.stringify(data, null, 2);
  }
}
