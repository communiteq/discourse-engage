export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("discourse-engage-surveys", { path: "surveys" }, function () {
      this.route("edit", { path: "/:survey_id/edit" });
      this.route("entries", { path: "/:survey_id/entries" });
    });
  },
};
