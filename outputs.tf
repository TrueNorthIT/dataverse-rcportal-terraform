output "scope" {
  value = var.scope
}

output "published_tables" {
  value = {
    for t in [
      dataversecontact_table.contact,
      dataversecontact_table.account,
      dataversecontact_table.opportunity,
      dataversecontact_table.quote,
      dataversecontact_table.case,
      ] : t.route_name => {
      id              = t.id
      dataverse_table = t.dataverse_table
      field_count     = t.field_count
    }
  }
}

output "permission_count" {
  value = dataversecontact_permissions_sync.rcportal.permission_count
}
