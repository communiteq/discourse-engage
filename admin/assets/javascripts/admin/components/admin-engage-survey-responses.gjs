import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn, get } from "@ember/helper";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminEngageSurveyResponses extends Component {
  @service dialog;

  @tracked expandedRows = {};
  @tracked exporting = false;
  @tracked entries = this.args.entries || [];

  get hasEntries() {
    return this.entries.length > 0;
  }

  @action
  toggleExpand(entryId) {
    this.expandedRows = {
      ...this.expandedRows,
      [entryId]: !this.expandedRows[entryId],
    };
  }

  @action
  async exportCsv() {
    this.exporting = true;

    try {
      const surveyId = this.args.survey.id;
      const url = `/admin/plugins/discourse-engage/api/surveys/${surveyId}/export`;

      const response = await fetch(url, {
        credentials: "same-origin",
        headers: {
          Accept: "text/csv",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
        },
      });

      if (!response.ok) {
        throw new Error("Export failed");
      }

      const contentType = response.headers.get("content-type") || "";
      if (!contentType.includes("text/csv")) {
        throw new Error("Export did not return CSV data");
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
          @label="discourse_engage.admin.export_csv"
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
            {{#each this.entries as |entry|}}
              <tr class="entry-row">
                <td>{{entry.username}}</td>
                <td>{{entry.submitted_at}}</td>
                <td class="entry-actions">
                  <DButton
                    @label="discourse_engage.admin.delete_entry"
                    @action={{fn this.deleteEntry entry}}
                    @icon="trash-can"
                    class="btn-small btn-danger"
                  />
                  <button
                    type="button"
                    {{on "click" (fn this.toggleExpand entry.entry_id)}}
                    class="btn btn-small"
                  >
                    {{#if (get this.expandedRows entry.entry_id)}}
                      {{i18n "discourse_engage.admin.hide_data"}}
                    {{else}}
                      {{i18n "discourse_engage.admin.show_data"}}
                    {{/if}}
                  </button>
                </td>
              </tr>
              {{#if (get this.expandedRows entry.entry_id)}}
                <tr class="entry-expanded">
                  <td colspan="3">
                    <div class="entry-data">
                      <h4>{{i18n "discourse_engage.admin.answers"}}</h4>
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
  deleteEntry(entry) {
    this.dialog.confirm({
      message: i18n("discourse_engage.admin.delete_entry_confirm"),
      didConfirm: async () => {
        try {
          const surveyId = this.args.survey.id;
          await ajax(
            `/admin/plugins/discourse-engage/api/surveys/${surveyId}/entries/${entry.user_id}/${entry.response_id}`,
            { type: "DELETE" },
          );
          this.entries = this.entries.filter(
            (e) => e.entry_id !== entry.entry_id,
          );
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  formatJson(data) {
    return JSON.stringify(data, null, 2);
  }
}
