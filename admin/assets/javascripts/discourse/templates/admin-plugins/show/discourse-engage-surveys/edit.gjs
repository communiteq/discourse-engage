import { LinkTo } from "@ember/routing";
import AdminEngageSurveyEdit from "../../../../admin/components/admin-engage-survey-edit";

export default <template>
  <div class="admin-detail engage-admin">
    <div class="engage-admin-header">
      <LinkTo
        @route="adminPlugins.show.discourse-engage-surveys"
        class="btn btn-default"
      >← Back to Surveys</LinkTo>
    </div>
    <AdminEngageSurveyEdit @survey={{@model}} />
  </div>
</template>;
