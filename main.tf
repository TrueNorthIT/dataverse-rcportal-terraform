terraform {
  required_providers {
    dataversecontact = {
      source = "tnapps/dataversecontact"
    }
  }
}

# Auth: the pre-shared admin connection key (sent as the admin Bearer token).
# The SAME value must be set as ADMIN_CONNECTION_KEY on the Contact API.
# Set DATAVERSE_CONTACT_CONNECTION_KEY in .env (run.sh exports it as TF_VAR_connection_key).
provider "dataversecontact" {
  api_url        = var.api_url
  connection_key = var.connection_key
}

# ── contact ───────────────────────────────────────────────────────────────
# me   = the signed-in user's own contact record
# team = every contact at the same account (colleagues)
resource "dataversecontact_table" "contact" {
  scope                  = var.scope
  route_name             = "contact"
  description            = "Customer contacts — your own profile (me) and colleagues at your company (team)"
  dataverse_table        = "contacts"
  dataverse_logical_name = "contact"
  primary_key            = "contactid"
  required_permission    = "contact"
  filters                = ["statecode eq 0"]
  aliases                = ["contacts"]

  default_select = [
    "contactid", "fullname", "firstname", "lastname", "emailaddress1",
    "jobtitle", "department", "telephone1", "mobilephone",
    "address1_line1", "address1_city", "address1_postalcode", "address1_country",
    "donotbulkemail", "createdon", "modifiedon",
  ]

  lookup_fields          = ["fullname", "emailaddress1"]
  lookup_search_contains = ["fullname", "emailaddress1"]

  # me: the contact is itself
  contact_join_step {
    table = "contacts"
    from  = "contactid"
    key   = "contactid"
  }

  # team: contact → its parent account
  team_join_step {
    table = "accounts"
    from  = "parentcustomerid_account"
    key   = "accountid"
  }

  expand {
    lookup_field  = "parentcustomerid_account"
    related_table = "account"

    field {
      name        = "accountid"
      type        = "string"
      description = "Account ID"
    }
    field {
      name        = "name"
      type        = "string"
      description = "Account name"
    }
  }

  fields = {
    contactid           = { type = "string", description = "Unique contact identifier", read_only = true }
    fullname            = { type = "string", description = "Full name", read_only = true }
    firstname           = { type = "string", description = "First name" }
    lastname            = { type = "string", description = "Last name" }
    emailaddress1       = { type = "string", description = "Primary email address" }
    jobtitle            = { type = "string", description = "Job title" }
    department          = { type = "string", description = "Department" }
    telephone1          = { type = "string", description = "Business phone" }
    mobilephone         = { type = "string", description = "Mobile phone" }
    address1_line1      = { type = "string", description = "Address line 1" }
    address1_city       = { type = "string", description = "City" }
    address1_postalcode = { type = "string", description = "Postcode" }
    address1_country    = { type = "string", description = "Country" }
    donotbulkemail      = { type = "boolean", description = "Opted out of marketing email" }
    # Note: parentcustomerid_account (the company link) is a polymorphic
    # navigation property, not a scalar column — it's used in team_join_step +
    # expand below, but must NOT be declared here (the API drops it, which
    # trips a provider state-consistency error).
    statecode  = { type = "choice", description = "Record status", read_only = true }
    createdon  = { type = "datetime", description = "Date created", read_only = true }
    modifiedon = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── account ─────────────────────────────────────────────────────────────────
# me   = the account where the signed-in contact is the primary contact
# team = the signed-in contact's own account
resource "dataversecontact_table" "account" {
  scope                  = var.scope
  route_name             = "account"
  description            = "Customer companies — your organisation (team) and accounts you're the primary contact for (me)"
  dataverse_table        = "accounts"
  dataverse_logical_name = "account"
  primary_key            = "accountid"
  required_permission    = "account"
  filters                = ["statecode eq 0"]

  default_select = [
    "accountid", "name", "telephone1", "emailaddress1", "websiteurl",
    "address1_city", "createdon", "modifiedon",
  ]

  lookup_fields          = ["name"]
  lookup_search_contains = ["name"]

  # me: account → its primary contact
  contact_join_step {
    table = "contacts"
    from  = "primarycontactid"
    key   = "contactid"
  }

  # team: the account itself
  team_join_step {
    table = "accounts"
    from  = "accountid"
    key   = "accountid"
  }

  expand {
    lookup_field  = "primarycontactid"
    related_table = "contact"

    field {
      name        = "fullname"
      type        = "string"
      description = "Primary contact full name"
    }
    field {
      name        = "emailaddress1"
      type        = "string"
      description = "Primary contact email"
    }
  }

  fields = {
    accountid                = { type = "string", description = "Unique account identifier", read_only = true }
    name                     = { type = "string", description = "Company name" }
    telephone1               = { type = "string", description = "Main phone" }
    emailaddress1            = { type = "string", description = "Primary email" }
    websiteurl               = { type = "string", description = "Website" }
    address1_line1           = { type = "string", description = "Address line 1" }
    address1_city            = { type = "string", description = "City" }
    address1_stateorprovince = { type = "string", description = "County" }
    address1_postalcode      = { type = "string", description = "Postcode" }
    address1_country         = { type = "string", description = "Country" }
    primarycontactid         = { type = "lookup", description = "Primary contact", lookup_table = "contact" }
    statecode                = { type = "choice", description = "Record status", read_only = true }
    createdon                = { type = "datetime", description = "Date created", read_only = true }
    modifiedon               = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── opportunity ───────────────────────────────────────────────────────────
# me   = opportunities where the signed-in contact is the primary contact
# team = every opportunity for the signed-in contact's account
resource "dataversecontact_table" "opportunity" {
  scope                  = var.scope
  route_name             = "opportunity"
  description            = "Sales opportunities — yours (me) and your company's whole pipeline (team)"
  dataverse_table        = "opportunities"
  dataverse_logical_name = "opportunity"
  primary_key            = "opportunityid"
  required_permission    = "opportunity"
  filters                = ["statecode eq 0"]
  aliases                = ["opportunities", "opps"]

  default_select = [
    "opportunityid", "name", "estimatedvalue", "estimatedclosedate",
    "statecode", "statuscode", "createdon", "modifiedon",
  ]

  lookup_fields          = ["name"]
  lookup_search_contains = ["name"]

  # me: opportunity → its primary contact
  contact_join_step {
    table = "contacts"
    from  = "parentcontactid"
    key   = "contactid"
  }

  # team: opportunity → customer account
  team_join_step {
    table = "accounts"
    from  = "customerid_account"
    key   = "accountid"
  }

  # NOTE: opportunities are READ-ONLY for portal customers — an opportunity is
  # Redcentric's own sales pipeline pursuing the customer, not something the
  # customer authors. No create_default; no create/write in the permission sync.

  fields = {
    opportunityid      = { type = "string", description = "Unique opportunity identifier", read_only = true }
    name               = { type = "string", description = "Opportunity name" }
    estimatedvalue     = { type = "number", description = "Estimated value (£)" }
    estimatedclosedate = { type = "datetime", description = "Estimated close date" }
    description        = { type = "string", description = "Notes" }
    statecode          = { type = "choice", description = "Status (Open/Won/Lost)" }
    statuscode         = { type = "choice", description = "Status reason" }
    customerid         = { type = "lookup", description = "Customer (account)", read_only = true }
    parentcontactid    = { type = "lookup", description = "Primary contact", lookup_table = "contact" }
    parentaccountid    = { type = "lookup", description = "Account", lookup_table = "account", read_only = true }
    createdon          = { type = "datetime", description = "Date created", read_only = true }
    modifiedon         = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── quote ─────────────────────────────────────────────────────────────────
# me   = quotes on your own opportunities (quote → opportunity → contact)
# team = every quote for your company's account
resource "dataversecontact_table" "quote" {
  scope                  = var.scope
  route_name             = "quote"
  description            = "Sales quotes — those on your opportunities (me) and your company's (team)"
  dataverse_table        = "quotes"
  dataverse_logical_name = "quote"
  primary_key            = "quoteid"
  required_permission    = "quote"
  aliases                = ["quotes"]
  # Show quotes in every state (Draft/Active/Won/Closed), not just the provider
  # default of statecode eq 0 (Draft) — a customer should see their issued and
  # active quotes, and the portal's status pills do the filtering.
  filters = []

  default_select = [
    "quoteid", "name", "quotenumber", "totalamount", "description",
    "effectivefrom", "effectiveto", "discountamount", "totaltax", "freightamount",
    "opportunityid", "statecode", "statuscode", "createdon", "modifiedon",
  ]

  lookup_fields          = ["name", "quotenumber"]
  lookup_search_contains = ["name", "quotenumber"]

  # me: quote → opportunity → primary contact (two-hop)
  contact_join_step {
    table = "opportunities"
    from  = "opportunityid"
    key   = "opportunityid"
  }
  contact_join_step {
    table = "contacts"
    from  = "parentcontactid"
    key   = "contactid"
  }

  # team: quote → customer account
  team_join_step {
    table = "accounts"
    from  = "customerid_account"
    key   = "accountid"
  }

  fields = {
    quoteid       = { type = "string", description = "Unique quote identifier", read_only = true }
    name          = { type = "string", description = "Quote name" }
    quotenumber   = { type = "string", description = "Quote number", read_only = true }
    totalamount   = { type = "number", description = "Total amount (£)", read_only = true }
    description   = { type = "string", description = "Notes" }
    effectivefrom = { type = "datetime", description = "Valid from", read_only = true }
    effectiveto   = { type = "datetime", description = "Valid until", read_only = true }
    discountamount = { type = "number", description = "Discount (£)", read_only = true }
    totaltax      = { type = "number", description = "Tax (£)", read_only = true }
    freightamount = { type = "number", description = "Delivery/setup (£)", read_only = true }
    statecode     = { type = "choice", description = "Status (Draft/Active/Won/Closed)" }
    statuscode    = { type = "choice", description = "Status reason" }
    customerid    = { type = "lookup", description = "Customer (account)", read_only = true }
    opportunityid = { type = "lookup", description = "Source opportunity", lookup_table = "opportunity" }
    createdon     = { type = "datetime", description = "Date created", read_only = true }
    modifiedon    = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── quotedetail (quote line items) ──────────────────────────────────────────
# Read-only line items on a quote. A child of quote (like casenotes → case):
# scoped through the parent quote, mirroring the quote route's joins one hop
# deeper via quotedetail → quote.
#   me   = lines on quotes on your opportunities (line → quote → opp → contact)
#   team = lines on your company's quotes        (line → quote → account)
resource "dataversecontact_table" "quotedetail" {
  scope                  = var.scope
  route_name             = "quotedetail"
  description            = "Line items on a quote"
  dataverse_table        = "quotedetails"
  dataverse_logical_name = "quotedetail"
  primary_key            = "quotedetailid"
  # Share the quote permission group: anyone who can see a quote can see its
  # lines — no separate quotedetail permission to grant or drift.
  required_permission = "quote"
  permission_group    = "quote"
  filters             = []
  aliases             = ["quotedetails", "quotelines", "quoteline"]

  default_select = [
    "quotedetailid", "productdescription", "priceperunit", "quantity",
    "extendedamount", "quoteid", "createdon",
  ]

  lookup_fields          = ["productdescription"]
  lookup_search_contains = ["productdescription"]

  # me: line → its quote → the quote's opportunity → that opp's primary contact
  contact_join_step {
    table = "quotes"
    from  = "quoteid"
    key   = "quoteid"
  }
  contact_join_step {
    table = "opportunities"
    from  = "opportunityid"
    key   = "opportunityid"
  }
  contact_join_step {
    table = "contacts"
    from  = "parentcontactid"
    key   = "contactid"
  }

  # team: line → its quote → the quote's customer account
  team_join_step {
    table = "quotes"
    from  = "quoteid"
    key   = "quoteid"
  }
  team_join_step {
    table = "accounts"
    from  = "customerid_account"
    key   = "accountid"
  }

  fields = {
    quotedetailid      = { type = "string", description = "Unique line identifier", read_only = true }
    productdescription = { type = "string", description = "Line item" }
    priceperunit       = { type = "number", description = "Unit price (£)", read_only = true }
    quantity           = { type = "number", description = "Quantity", read_only = true }
    extendedamount     = { type = "number", description = "Line total (£)", read_only = true }
    quoteid            = { type = "lookup", description = "Quote", lookup_table = "quote", read_only = true }
    createdon          = { type = "datetime", description = "Date created", read_only = true }
  }
}

# ── case (incident) ─────────────────────────────────────────────────────────
# The one thing a customer genuinely creates in a self-service portal: a support
# ticket. me = cases the signed-in contact raised; team = every case for their
# company's account. Create auto-binds the caller's contact + account.
resource "dataversecontact_table" "case" {
  scope                  = var.scope
  route_name             = "case"
  description            = "Support cases — tickets you raised (me) and your company's (team)"
  dataverse_table        = "incidents"
  dataverse_logical_name = "incident"
  primary_key            = "incidentid"
  required_permission    = "case"
  filters                = ["statecode eq 0"]
  aliases                = ["cases", "incidents", "tickets"]

  # `description` must be here: the single-record GET uses default_select (it
  # ignores the client's ?select), so without it the case detail description
  # came back empty even though the list showed it.
  default_select = [
    "incidentid", "title", "ticketnumber", "prioritycode",
    "statecode", "statuscode", "description", "createdon", "modifiedon",
  ]

  lookup_fields          = ["title", "ticketnumber"]
  lookup_search_contains = ["title", "ticketnumber"]

  # me: case → its primary contact
  contact_join_step {
    table = "contacts"
    from  = "primarycontactid"
    key   = "contactid"
  }

  # team: case → customer account
  team_join_step {
    table = "accounts"
    from  = "customerid_account"
    key   = "accountid"
  }

  # On create, bind the case to the caller's own contact + account from the
  # verified token — the customer only supplies title/description/priority.
  create_default {
    field      = "primarycontactid"
    bind_to    = "contact"
    entity_set = "contacts"
  }
  create_default {
    field      = "customerid_account"
    bind_to    = "account"
    entity_set = "accounts"
  }

  fields = {
    incidentid       = { type = "string", description = "Unique case identifier", read_only = true }
    title            = { type = "string", description = "Summary" }
    description      = { type = "string", description = "Details" }
    ticketnumber     = { type = "string", description = "Case number", read_only = true }
    prioritycode     = { type = "choice", description = "Priority" }
    statecode        = { type = "choice", description = "Status (Active/Resolved/Cancelled)", read_only = true }
    statuscode       = { type = "choice", description = "Status reason", read_only = true }
    customerid       = { type = "lookup", description = "Customer (account)", read_only = true }
    primarycontactid = { type = "lookup", description = "Primary contact", lookup_table = "contact", read_only = true }
    createdon        = { type = "datetime", description = "Date created", read_only = true }
    modifiedon       = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── casenotes (annotation) ──────────────────────────────────────────────────
# The read-only notes/updates timeline on a support case. Restricted to notes
# whose "regarding" record is an incident (objecttypecode). Scoped through the
# parent case, mirroring the case route's joins:
#   me   = notes on cases you raised   (note → incident → primarycontactid)
#   team = notes on your company's cases (note → incident → customerid_account)
resource "dataversecontact_table" "casenotes" {
  scope                  = var.scope
  route_name             = "casenotes"
  description            = "Notes and updates on your support cases"
  dataverse_table        = "annotations"
  dataverse_logical_name = "annotation"
  primary_key            = "annotationid"
  # Notes are a child of the case: share the case's permission group so anyone
  # who can see a case can see its notes — no separate casenotes permission to
  # grant or drift. parent_table declares that relationship.
  required_permission = "case"
  permission_group    = "case"
  filters             = ["objecttypecode eq 'incident'"]
  aliases             = ["casenote", "notes"]

  default_select = [
    "annotationid", "subject", "notetext", "objectid",
    "objecttypecode", "isdocument", "createdon", "modifiedon",
  ]

  lookup_fields          = ["subject"]
  lookup_search_contains = ["subject"]

  # me: note → its incident → the incident's primary contact
  contact_join_step {
    table = "incidents"
    from  = "objectid_incident"
    key   = "incidentid"
  }
  contact_join_step {
    table = "contacts"
    from  = "primarycontactid"
    key   = "contactid"
  }

  # team: note → its incident → the incident's customer account
  team_join_step {
    table = "incidents"
    from  = "objectid_incident"
    key   = "incidentid"
  }
  team_join_step {
    table = "accounts"
    from  = "customerid_account"
    key   = "accountid"
  }

  # A note's parent is the case, reached via the polymorphic objectid → incident.
  parent_table {
    table               = "case"
    navigation_property = "objectid_incident"
  }

  fields = {
    annotationid   = { type = "string", description = "Unique note identifier", read_only = true }
    subject        = { type = "string", description = "Note subject" }
    notetext       = { type = "string", description = "Note text" }
    # Writable so the portal can add a note to a case: sending `objectid: <caseId>`
    # binds via objectid_incident → /incidents(id). entitySet is derived from
    # lookup_table ("case" → incidents).
    objectid       = { type = "lookup", description = "Regarding case", lookup_table = "case", bind_field = "objectid_incident" }
    objecttypecode = { type = "string", description = "Regarding entity type", read_only = true }
    isdocument     = { type = "boolean", description = "Has attachment", read_only = true }
    createdon      = { type = "datetime", description = "Date created", read_only = true }
    modifiedon     = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── project (msdyn_project) ─────────────────────────────────────────────────
# Delivery projects (Project Operations). msdyn_project links only to the
# customer *account* (msdyn_customer) — there is no project→contact field — so:
#   me   = projects for the account you're the primary contact of (2-hop:
#          project → customer account → account.primarycontactid = you)
#   team = every project for your company's account
# Read-only: customers view delivery status, they don't author projects.
resource "dataversecontact_table" "project" {
  scope                  = var.scope
  route_name             = "project"
  description            = "Delivery projects — for the account you're the primary contact of (me) and your company's (team)"
  dataverse_table        = "msdyn_projects"
  dataverse_logical_name = "msdyn_project"
  primary_key            = "msdyn_projectid"
  required_permission    = "project"
  filters                = ["statecode eq 0"]
  aliases                = ["projects", "msdyn_projects"]

  default_select = [
    "msdyn_projectid", "msdyn_subject", "msdyn_description",
    "msdyn_scheduledstart", "msdyn_finish", "msdyn_actualstart", "msdyn_actualend",
    "statecode", "statuscode", "createdon", "modifiedon",
  ]

  lookup_fields          = ["msdyn_subject"]
  lookup_search_contains = ["msdyn_subject"]

  # Account link is the native `msdyn_customer` lookup (nav property matches its
  # logical name — the seed data populates it).
  # me: project → customer account → its primary contact (two-hop)
  contact_join_step {
    table = "accounts"
    from  = "msdyn_customer"
    key   = "accountid"
  }
  contact_join_step {
    table = "contacts"
    from  = "primarycontactid"
    key   = "contactid"
  }

  # team: project → customer account
  team_join_step {
    table = "accounts"
    from  = "msdyn_customer"
    key   = "accountid"
  }

  fields = {
    msdyn_projectid      = { type = "string", description = "Unique project identifier", read_only = true }
    msdyn_subject        = { type = "string", description = "Project name" }
    msdyn_description    = { type = "string", description = "Description" }
    msdyn_scheduledstart = { type = "datetime", description = "Scheduled start" }
    msdyn_finish         = { type = "datetime", description = "Scheduled finish" }
    msdyn_actualstart    = { type = "datetime", description = "Actual start", read_only = true }
    msdyn_actualend      = { type = "datetime", description = "Actual finish", read_only = true }
    msdyn_customer       = { type = "lookup", description = "Customer (account)", lookup_table = "account", read_only = true }
    statecode            = { type = "choice", description = "Status", read_only = true }
    statuscode           = { type = "choice", description = "Status reason", read_only = true }
    createdon            = { type = "datetime", description = "Date created", read_only = true }
    modifiedon           = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── projectnotes (annotation) ───────────────────────────────────────────────
# The project delivery diary — annotations whose "regarding" record is a
# project (objecttypecode). Scoped through the parent project, mirroring the
# project route's joins one hop deeper via note → project:
#   me   = notes on projects for the account you're the primary contact of
#   team = notes on your company's projects
# (Project for the Web blocks direct msdyn_projecttask writes, so the diary —
# real, writable annotations — is how we surface genuine per-project updates.)
resource "dataversecontact_table" "projectnotes" {
  scope                  = var.scope
  route_name             = "projectnotes"
  description            = "Delivery notes/updates on your projects"
  dataverse_table        = "annotations"
  dataverse_logical_name = "annotation"
  primary_key            = "annotationid"
  required_permission    = "project"
  permission_group       = "project"
  filters                = ["objecttypecode eq 'msdyn_project'"]
  aliases                = ["projectnote"]

  default_select = [
    "annotationid", "subject", "notetext", "objectid",
    "objecttypecode", "createdon", "modifiedon",
  ]

  lookup_fields          = ["subject"]
  lookup_search_contains = ["subject"]

  # me: note → its project → the project's customer account → its primary contact
  contact_join_step {
    table = "msdyn_projects"
    from  = "objectid_msdyn_project"
    key   = "msdyn_projectid"
  }
  contact_join_step {
    table = "accounts"
    from  = "msdyn_customer"
    key   = "accountid"
  }
  contact_join_step {
    table = "contacts"
    from  = "primarycontactid"
    key   = "contactid"
  }

  # team: note → its project → the project's customer account
  team_join_step {
    table = "msdyn_projects"
    from  = "objectid_msdyn_project"
    key   = "msdyn_projectid"
  }
  team_join_step {
    table = "accounts"
    from  = "msdyn_customer"
    key   = "accountid"
  }

  # A note's parent is the project, via the polymorphic objectid → msdyn_project.
  parent_table {
    table               = "project"
    navigation_property = "objectid_msdyn_project"
  }

  fields = {
    annotationid   = { type = "string", description = "Unique note identifier", read_only = true }
    subject        = { type = "string", description = "Note subject" }
    notetext       = { type = "string", description = "Note text" }
    objectid       = { type = "lookup", description = "Regarding project", lookup_table = "project", bind_field = "objectid_msdyn_project" }
    objecttypecode = { type = "string", description = "Regarding entity type", read_only = true }
    createdon      = { type = "datetime", description = "Date created", read_only = true }
    modifiedon     = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── projecttask (new_projecttask, custom) ───────────────────────────────────
# The project delivery plan — phase bars + milestones as real rows in a custom
# table (Project for the Web blocks msdyn_projecttask writes, so we model plan
# items here). Read-only; scoped through the parent project like projectnotes.
resource "dataversecontact_table" "projecttask" {
  scope                  = var.scope
  route_name             = "projecttask"
  description            = "Delivery plan items (phases + milestones) for your projects"
  dataverse_table        = "new_projecttasks"
  dataverse_logical_name = "new_projecttask"
  primary_key            = "new_projecttaskid"
  required_permission    = "project"
  permission_group       = "project"
  filters                = []
  aliases                = ["projecttasks", "planitems"]

  default_select = [
    "new_projecttaskid", "new_name", "new_startdate", "new_enddate",
    "new_ismilestone", "new_percentcomplete", "new_sequence", "new_projectid", "createdon",
  ]

  lookup_fields          = ["new_name"]
  lookup_search_contains = ["new_name"]

  # me: task → its project → the project's customer account → its primary contact
  contact_join_step {
    table = "msdyn_projects"
    from  = "new_ProjectId"
    key   = "msdyn_projectid"
  }
  contact_join_step {
    table = "accounts"
    from  = "msdyn_customer"
    key   = "accountid"
  }
  contact_join_step {
    table = "contacts"
    from  = "primarycontactid"
    key   = "contactid"
  }

  # team: task → its project → the project's customer account
  team_join_step {
    table = "msdyn_projects"
    from  = "new_ProjectId"
    key   = "msdyn_projectid"
  }
  team_join_step {
    table = "accounts"
    from  = "msdyn_customer"
    key   = "accountid"
  }

  fields = {
    new_projecttaskid   = { type = "string", description = "Unique task identifier", read_only = true }
    new_name            = { type = "string", description = "Task" }
    new_startdate       = { type = "datetime", description = "Start date" }
    new_enddate         = { type = "datetime", description = "End date" }
    new_ismilestone     = { type = "boolean", description = "Is milestone" }
    new_percentcomplete = { type = "number", description = "Percent complete" }
    new_sequence        = { type = "number", description = "Sequence" }
    # bind_field is the cased nav property the API auto-discovers for this
    # single-relationship lookup; declared here so Terraform state converges.
    new_projectid       = { type = "lookup", description = "Project", lookup_table = "project", bind_field = "new_ProjectId", read_only = true }
    createdon           = { type = "datetime", description = "Date created", read_only = true }
  }
}

# ── site (customeraddress) ──────────────────────────────────────────────────
# Customer locations/premises. `site` (Field Service) is Microsoft-locked and
# has no account link, so sites are modelled on customeraddress — the native
# "More Addresses" table that parents to account via `parentid`.
#   me   = locations of the account you're the primary contact of (2-hop)
#   team = every location for your company's account
# Read-only: customers view their sites, they don't author them here.
resource "dataversecontact_table" "site" {
  scope                  = var.scope
  route_name             = "site"
  description            = "Customer sites — your company's locations/premises"
  dataverse_table        = "customeraddresses"
  dataverse_logical_name = "customeraddress"
  primary_key            = "customeraddressid"
  required_permission    = "site"
  aliases                = ["sites", "locations", "customeraddress"]

  # customeraddress has no statecode, so override the default ["statecode eq 0"]
  # filter. `name ne null` also cleanly hides the auto-created address1/address2
  # rows (null name), leaving just the real named sites.
  filters = ["name ne null"]

  # NB: line3 deliberately excluded — it holds the [DEMO-RCPORTAL] seed marker.
  default_select = [
    "customeraddressid", "name", "line1", "line2", "city",
    "stateorprovince", "postalcode", "country", "telephone1",
    "latitude", "longitude", "addresstypecode", "new_connectivitytype", "createdon",
  ]

  lookup_fields          = ["name", "city"]
  lookup_search_contains = ["name", "city"]

  # me: site → parent account → its primary contact (two-hop)
  contact_join_step {
    table = "accounts"
    from  = "parentid_account"
    key   = "accountid"
  }
  contact_join_step {
    table = "contacts"
    from  = "primarycontactid"
    key   = "contactid"
  }

  # team: site → parent account
  team_join_step {
    table = "accounts"
    from  = "parentid_account"
    key   = "accountid"
  }

  fields = {
    customeraddressid = { type = "string", description = "Unique site identifier", read_only = true }
    name              = { type = "string", description = "Site name" }
    line1             = { type = "string", description = "Address line 1" }
    line2             = { type = "string", description = "Address line 2" }
    city              = { type = "string", description = "City" }
    stateorprovince   = { type = "string", description = "County" }
    postalcode        = { type = "string", description = "Postcode" }
    country           = { type = "string", description = "Country" }
    telephone1        = { type = "string", description = "Site phone" }
    latitude             = { type = "number", description = "Latitude", read_only = true }
    longitude            = { type = "number", description = "Longitude", read_only = true }
    addresstypecode      = { type = "choice", description = "Address type" }
    new_connectivitytype = { type = "choice", description = "Connectivity type" }
    createdon            = { type = "datetime", description = "Date created", read_only = true }
  }
}

# ── portalfeedback (new_portalfeedback, custom table) ───────────────────────
# Customer feedback about the portal itself. Create-capable; the customer sees
# their own (me) and their company's (team). Auto-binds contact + account on
# create so the form only sends message/category/rating.
resource "dataversecontact_table" "portalfeedback" {
  scope                  = var.scope
  route_name             = "portalfeedback"
  description            = "Portal feedback — yours (me) and your company's (team)"
  dataverse_table        = "new_portalfeedbacks"
  dataverse_logical_name = "new_portalfeedback"
  primary_key            = "new_portalfeedbackid"
  required_permission    = "portalfeedback"
  aliases                = ["feedback"]

  default_select = [
    "new_portalfeedbackid", "new_name", "new_message", "new_category",
    "new_rating", "createdon", "modifiedon",
  ]

  lookup_fields          = ["new_name"]
  lookup_search_contains = ["new_name"]

  # me: feedback → the contact who submitted it
  contact_join_step {
    table = "contacts"
    from  = "new_contactid"
    key   = "contactid"
  }

  # team: feedback → the submitter's account
  team_join_step {
    table = "accounts"
    from  = "new_accountid"
    key   = "accountid"
  }

  # On create, bind the caller's own contact + account from the verified token.
  create_default {
    field      = "new_contactid"
    bind_to    = "contact"
    entity_set = "contacts"
  }
  create_default {
    field      = "new_accountid"
    bind_to    = "account"
    entity_set = "accounts"
  }

  fields = {
    new_portalfeedbackid = { type = "string", description = "Unique feedback identifier", read_only = true }
    new_name             = { type = "string", description = "Summary" }
    new_message          = { type = "string", description = "Feedback message" }
    new_category         = { type = "choice", description = "Category (Bug/Idea/Praise/Question/Other)" }
    new_rating           = { type = "number", description = "Rating 1–5" }
    # bind_field = the schema-cased navigation property (not the logical name) —
    # the @odata.bind on create must use new_ContactId / new_AccountId.
    new_contactid        = { type = "lookup", description = "Submitted by", lookup_table = "contact", bind_field = "new_ContactId", read_only = true }
    new_accountid        = { type = "lookup", description = "Company", lookup_table = "account", bind_field = "new_AccountId", read_only = true }
    createdon            = { type = "datetime", description = "Date created", read_only = true }
    modifiedon           = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── knowledgearticle (D365 Knowledge Base) ──────────────────────────────────
# Public, read-only self-service KB. Org-wide (no contact/account scoping);
# public_read exposes it on the unauthenticated /public tier. Only published
# articles (statecode 3). `content` is rich HTML rendered by the portal.
resource "dataversecontact_table" "knowledgearticle" {
  scope                  = var.scope
  route_name             = "knowledgearticle"
  description            = "Knowledge base articles (published)"
  dataverse_table        = "knowledgearticles"
  dataverse_logical_name = "knowledgearticle"
  primary_key            = "knowledgearticleid"
  required_permission    = "knowledgearticle"
  public_read            = true
  filters                = ["statecode eq 3"]
  aliases                = ["kb", "knowledge"]

  default_select = [
    "knowledgearticleid", "title", "description", "content",
    "articlepublicnumber", "keywords", "createdon", "modifiedon",
  ]

  lookup_fields          = ["title"]
  lookup_search_contains = ["title"]

  fields = {
    knowledgearticleid  = { type = "string", description = "Unique article identifier", read_only = true }
    title               = { type = "string", description = "Article title", read_only = true }
    description         = { type = "string", description = "Short summary", read_only = true }
    content             = { type = "string", description = "Article body (HTML)", read_only = true }
    articlepublicnumber = { type = "string", description = "Public article number", read_only = true }
    keywords            = { type = "string", description = "Keywords", read_only = true }
    statecode           = { type = "choice", description = "Status", read_only = true }
    createdon           = { type = "datetime", description = "Date created", read_only = true }
    modifiedon          = { type = "datetime", description = "Date last modified", read_only = true }
  }
}

# ── Permission sync ─────────────────────────────────────────────────────────
# Customer self-service portal: the customer manages only their own identity
# and raises support cases. Everything about Redcentric's sales/delivery
# relationship (accounts, opportunities, quotes, projects, sites) is READ-ONLY.
resource "dataversecontact_permissions_sync" "rcportal" {
  scope = var.scope

  # Let a signed-in user with no contact yet self-provision one via
  # POST /me/register (the portal's "join" screen).
  allow_self_register = true

  # (1) How we resolve which companies a person is a member of. Redcentric's
  # customers are one Dataverse contact per company (the classic model).
  company_model = {
    strategy = "parent-account"
  }

  # (2)+(3)+(4) How a new user may JOIN: match their verified email domain
  # against each company's `new_portaldomains` list. A company lists its own
  # domain(s) plus truenorthit.co.uk (so TrueNorth staff can join any). With
  # require_match, someone whose domain is on no company is blocked from signing
  # up at all (the UI shows "not a member of any trusted domain").
  join = {
    strategy      = "domain-list"
    domain_field  = "new_portaldomains"
    require_match = true
  }

  default_permissions = {
    contact     = ["me", "team", "write"]           # edit own profile; read colleagues
    account     = ["me", "team"]                    # read-only
    opportunity = ["me", "team"]                    # read-only (vendor's pipeline)
    quote       = ["me", "team"]                    # read-only (vendor-issued)
    project     = ["me", "team"]                    # read-only (delivery status)
    case          = ["me", "team", "write", "create"] # raise + view + update own tickets
    # casenotes has no entry — it shares the `case` permission group (see the
    # casenotes route's permission_group), so it inherits case's me/team access.
    site          = ["me", "team"]                    # read-only (locations)
    portalfeedback = ["me", "team", "write", "create"] # submit + view own/company feedback
    # knowledgearticle has no entry — public_read on the route governs access
    # (unauthenticated /public tier), so no per-contact permission is needed.
  }

  triggers = {
    tables_hash = sha256(join(",", [
      dataversecontact_table.contact.id,
      dataversecontact_table.account.id,
      dataversecontact_table.opportunity.id,
      dataversecontact_table.quote.id,
      dataversecontact_table.quotedetail.id,
      dataversecontact_table.project.id,
      dataversecontact_table.projectnotes.id,
      dataversecontact_table.projecttask.id,
      dataversecontact_table.case.id,
      dataversecontact_table.casenotes.id,
      dataversecontact_table.site.id,
      dataversecontact_table.portalfeedback.id,
      dataversecontact_table.knowledgearticle.id,
    ]))
  }

  depends_on = [
    dataversecontact_table.contact,
    dataversecontact_table.account,
    dataversecontact_table.opportunity,
    dataversecontact_table.quote,
    dataversecontact_table.quotedetail,
    dataversecontact_table.project,
    dataversecontact_table.projectnotes,
    dataversecontact_table.projecttask,
    dataversecontact_table.case,
    dataversecontact_table.casenotes,
    dataversecontact_table.site,
    dataversecontact_table.portalfeedback,
    dataversecontact_table.knowledgearticle,
  ]
}
