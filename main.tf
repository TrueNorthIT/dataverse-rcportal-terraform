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
    "jobtitle", "telephone1", "mobilephone", "address1_city",
    "createdon", "modifiedon",
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
    telephone1          = { type = "string", description = "Business phone" }
    mobilephone         = { type = "string", description = "Mobile phone" }
    address1_line1      = { type = "string", description = "Address line 1" }
    address1_city       = { type = "string", description = "City" }
    address1_postalcode = { type = "string", description = "Postcode" }
    address1_country    = { type = "string", description = "Country" }
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

  default_select = [
    "quoteid", "name", "quotenumber", "totalamount",
    "statecode", "statuscode", "createdon", "modifiedon",
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
    statecode     = { type = "choice", description = "Status (Draft/Active/Won/Closed)" }
    statuscode    = { type = "choice", description = "Status reason" }
    customerid    = { type = "lookup", description = "Customer (account)", read_only = true }
    opportunityid = { type = "lookup", description = "Source opportunity", lookup_table = "opportunity" }
    createdon     = { type = "datetime", description = "Date created", read_only = true }
    modifiedon    = { type = "datetime", description = "Date last modified", read_only = true }
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

  default_select = [
    "incidentid", "title", "ticketnumber", "prioritycode",
    "statecode", "statuscode", "createdon", "modifiedon",
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

# ── Permission sync ─────────────────────────────────────────────────────────
# Customer self-service portal: the customer manages only their own identity
# and raises support cases. Everything about Redcentric's sales/delivery
# relationship (accounts, opportunities, quotes) is READ-ONLY.
resource "dataversecontact_permissions_sync" "rcportal" {
  scope = var.scope

  default_permissions = {
    contact     = ["me", "team", "write"]           # edit own profile; read colleagues
    account     = ["me", "team"]                    # read-only
    opportunity = ["me", "team"]                    # read-only (vendor's pipeline)
    quote       = ["me", "team"]                    # read-only (vendor-issued)
    case        = ["me", "team", "write", "create"] # raise + view + update own tickets
  }

  triggers = {
    tables_hash = sha256(join(",", [
      dataversecontact_table.contact.id,
      dataversecontact_table.account.id,
      dataversecontact_table.opportunity.id,
      dataversecontact_table.quote.id,
      dataversecontact_table.case.id,
    ]))
  }

  depends_on = [
    dataversecontact_table.contact,
    dataversecontact_table.account,
    dataversecontact_table.opportunity,
    dataversecontact_table.quote,
    dataversecontact_table.case,
  ]
}
