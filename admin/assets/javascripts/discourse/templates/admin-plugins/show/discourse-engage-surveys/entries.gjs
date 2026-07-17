import { LinkTo } from "@ember/routing";
import AdminEngageSurveyResponses from "../../../../../admin/components/admin-engage-survey-responses";

export default <template>
  <div class="admin-detail engage-admin">
    <div class="engage-admin-header">
      <LinkTo
        @route="adminPlugins.show.discourse-engage-surveys"
        class="btn btn-default"
      >← Back to Surveys</LinkTo>
    </div>
    <AdminEngageSurveyResponses @survey={{@model.survey}} @entries={{@model.entries}} />
  </div>
</template>;
