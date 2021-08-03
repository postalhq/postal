class InitialSchema < ActiveRecord::Migration

  def up
    create_table "additional_route_endpoints", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "route_id"
      t.string   "endpoint_type"
      t.integer  "endpoint_id"
      t.datetime "created_at",    null: false
      t.datetime "updated_at",    null: false
    end

    create_table "address_endpoints", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "server_id"
      t.string   "uuid"
      t.string   "address"
      t.datetime "last_used_at"
      t.datetime "created_at",   null: false
      t.datetime "updated_at",   null: false
    end

    create_table "authie_sessions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "token"
      t.string   "browser_id"
      t.integer  "user_id"
      t.boolean  "active", default: true
      t.text     "data", limit: 65_535
      t.datetime "expires_at"
      t.datetime "login_at"
      t.string   "login_ip"
      t.datetime "last_activity_at"
      t.string   "last_activity_ip"
      t.string   "last_activity_path"
      t.string   "user_agent"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "user_type"
      t.integer  "parent_id"
      t.datetime "two_factored_at"
      t.string   "two_factored_ip"
      t.integer  "requests", default: 0
      t.datetime "password_seen_at"
      t.string   "token_hash"
      t.index ["browser_id"], name: "index_authie_sessions_on_browser_id", length: { browser_id: 8 }, using: :btree
      t.index ["token"], name: "index_authie_sessions_on_token", length: { token: 8 }, using: :btree
      t.index ["user_id"], name: "index_authie_sessions_on_user_id", using: :btree
    end

    create_table "credentials", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "server_id"
      t.string   "key"
      t.string   "type"
      t.string   "name"
      t.text     "options", limit: 65_535
      t.datetime "last_used_at",               precision: 6
      t.datetime "created_at",                 precision: 6
      t.datetime "updated_at",                 precision: 6
      t.boolean  "hold", default: false
    end

    create_table "domains", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "server_id"
      t.string   "uuid"
      t.string   "name"
      t.string   "verification_token"
      t.string   "verification_method"
      t.datetime "verified_at"
      t.text     "dkim_private_key", limit: 65_535
      t.datetime "created_at",                           precision: 6
      t.datetime "updated_at",                           precision: 6
      t.datetime "dns_checked_at",                       precision: 6
      t.string   "spf_status"
      t.string   "spf_error"
      t.string   "dkim_status"
      t.string   "dkim_error"
      t.string   "mx_status"
      t.string   "mx_error"
      t.string   "return_path_status"
      t.string   "return_path_error"
      t.boolean  "outgoing",                                           default: true
      t.boolean  "incoming",                                           default: true
      t.string   "owner_type"
      t.integer  "owner_id"
      t.string   "dkim_identifier_string"
      t.boolean  "use_for_any"
      t.index ["server_id"], name: "index_domains_on_server_id", using: :btree
      t.index ["uuid"], name: "index_domains_on_uuid", length: { uuid: 8 }, using: :btree
    end

    create_table "http_endpoints", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "server_id"
      t.string   "uuid"
      t.string   "name"
      t.string   "url"
      t.string   "encoding"
      t.string   "format"
      t.boolean  "strip_replies", default: false
      t.text     "error", limit: 65_535
      t.datetime "disabled_until",                    precision: 6
      t.datetime "last_used_at",                      precision: 6
      t.datetime "created_at",                        precision: 6
      t.datetime "updated_at",                        precision: 6
      t.boolean  "include_attachments", default: true
      t.integer  "timeout"
    end

    create_table "ip_addresses", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "ip_pool_id"
      t.string   "ipv4"
      t.string   "ipv6"
      t.datetime "created_at", precision: 6
      t.datetime "updated_at", precision: 6
      t.string   "hostname"
    end

    create_table "ip_pool_rules", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "uuid"
      t.string   "owner_type"
      t.integer  "owner_id"
      t.integer  "ip_pool_id"
      t.text     "from_text",  limit: 65_535
      t.text     "to_text",    limit: 65_535
      t.datetime "created_at",               null: false
      t.datetime "updated_at",               null: false
    end

    create_table "ip_pools", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "name"
      t.string   "uuid"
      t.datetime "created_at", precision: 6
      t.datetime "updated_at", precision: 6
      t.boolean  "default", default: false
      t.string   "type"
      t.index ["uuid"], name: "index_ip_pools_on_uuid", length: { uuid: 8 }, using: :btree
    end

    create_table "organization_ip_pools", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "organization_id"
      t.integer  "ip_pool_id"
      t.datetime "created_at",      null: false
      t.datetime "updated_at",      null: false
    end

    create_table "organization_users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "organization_id"
      t.integer  "user_id"
      t.datetime "created_at", precision: 6
      t.boolean  "admin",                         default: false
      t.boolean  "all_servers",                   default: true
      t.string   "user_type"
    end

    create_table "organizations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "uuid"
      t.string   "name"
      t.string   "permalink"
      t.string   "time_zone"
      t.datetime "created_at",        precision: 6
      t.datetime "updated_at",        precision: 6
      t.integer  "ip_pool_id"
      t.integer  "owner_id"
      t.datetime "deleted_at",        precision: 6
      t.datetime "suspended_at",      precision: 6
      t.string   "suspension_reason"
      t.index ["permalink"], name: "index_organizations_on_permalink", length: { permalink: 8 }, using: :btree
      t.index ["uuid"], name: "index_organizations_on_uuid", length: { uuid: 8 }, using: :btree
    end

    create_table "queued_messages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "server_id"
      t.integer  "message_id"
      t.string   "domain"
      t.string   "locked_by"
      t.datetime "locked_at", precision: 6
      t.datetime "retry_after"
      t.datetime "created_at",    precision: 6
      t.datetime "updated_at",    precision: 6
      t.integer  "ip_address_id"
      t.integer  "attempts", default: 0
      t.integer  "route_id"
      t.boolean  "manual", default: false
      t.string   "batch_key"
      t.index ["domain"], name: "index_queued_messages_on_domain", length: { domain: 8 }, using: :btree
      t.index ["message_id"], name: "index_queued_messages_on_message_id", using: :btree
      t.index ["server_id"], name: "index_queued_messages_on_server_id", using: :btree
    end

    create_table "routes", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "uuid"
      t.integer  "server_id"
      t.integer  "domain_id"
      t.integer  "endpoint_id"
      t.string   "endpoint_type"
      t.string   "name"
      t.string   "spam_mode"
      t.datetime "created_at",    precision: 6
      t.datetime "updated_at",    precision: 6
      t.string   "token"
      t.string   "mode"
      t.index ["token"], name: "index_routes_on_token", length: { token: 6 }, using: :btree
    end

    create_table "servers", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "organization_id"
      t.string   "uuid"
      t.string   "name"
      t.string   "mode"
      t.integer  "ip_pool_id"
      t.datetime "created_at",                                       precision: 6
      t.datetime "updated_at",                                       precision: 6
      t.string   "permalink"
      t.integer  "send_limit"
      t.datetime "deleted_at", precision: 6
      t.integer  "message_retention_days"
      t.integer  "raw_message_retention_days"
      t.integer  "raw_message_retention_size"
      t.boolean  "allow_sender", default: false
      t.string   "token"
      t.datetime "send_limit_approaching_at",                        precision: 6
      t.datetime "send_limit_approaching_notified_at",               precision: 6
      t.datetime "send_limit_exceeded_at",                           precision: 6
      t.datetime "send_limit_exceeded_notified_at",                  precision: 6
      t.decimal  "spam_threshold",                                   precision: 8, scale: 2
      t.decimal  "spam_failure_threshold",                           precision: 8, scale: 2
      t.string   "postmaster_address"
      t.datetime "suspended_at",                                     precision: 6
      t.decimal  "outbound_spam_threshold",                          precision: 8, scale: 2
      t.text     "domains_not_to_click_track", limit: 65_535
      t.string   "suspension_reason"
      t.boolean  "log_smtp_data", default: false
      t.index ["organization_id"], name: "index_servers_on_organization_id", using: :btree
      t.index ["permalink"], name: "index_servers_on_permalink", length: { permalink: 6 }, using: :btree
      t.index ["token"], name: "index_servers_on_token", length: { token: 6 }, using: :btree
      t.index ["uuid"], name: "index_servers_on_uuid", length: { uuid: 8 }, using: :btree
    end

    create_table "smtp_endpoints", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "server_id"
      t.string   "uuid"
      t.string   "name"
      t.string   "hostname"
      t.string   "ssl_mode"
      t.integer  "port"
      t.text     "error", limit: 65_535
      t.datetime "disabled_until",               precision: 6
      t.datetime "last_used_at",                 precision: 6
      t.datetime "created_at",                   precision: 6
      t.datetime "updated_at",                   precision: 6
    end

    create_table "statistics", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.bigint "total_messages", default: 0
      t.bigint "total_outgoing", default: 0
      t.bigint "total_incoming", default: 0
    end

    create_table "track_certificates", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "domain"
      t.text     "certificate",         limit: 65_535
      t.text     "intermediaries",      limit: 65_535
      t.text     "key",                 limit: 65_535
      t.datetime "expires_at"
      t.datetime "renew_after"
      t.string   "verification_path"
      t.string   "verification_string"
      t.datetime "created_at",                        null: false
      t.datetime "updated_at",                        null: false
      t.index ["domain"], name: "index_track_certificates_on_domain", length: { domain: 8 }, using: :btree
    end

    create_table "track_domains", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "uuid"
      t.integer  "server_id"
      t.integer  "domain_id"
      t.string   "name"
      t.datetime "dns_checked_at"
      t.string   "dns_status"
      t.string   "dns_error"
      t.datetime "created_at",                                          null: false
      t.datetime "updated_at",                                          null: false
      t.boolean  "ssl_enabled",                          default: true
      t.boolean  "track_clicks",                         default: true
      t.boolean  "track_loads",                          default: true
      t.text     "excluded_click_domains", limit: 65_535
    end

    create_table "user_invites", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "uuid"
      t.string   "email_address"
      t.datetime "expires_at",    precision: 6
      t.datetime "created_at",    precision: 6
      t.datetime "updated_at",    precision: 6
      t.index ["uuid"], name: "index_user_invites_on_uuid", length: { uuid: 12 }, using: :btree
    end

    create_table "users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "uuid"
      t.string   "first_name"
      t.string   "last_name"
      t.string   "email_address"
      t.string   "password_digest"
      t.string   "time_zone"
      t.string   "email_verification_token"
      t.datetime "email_verified_at"
      t.datetime "created_at",                       precision: 6
      t.datetime "updated_at",                       precision: 6
      t.string   "password_reset_token"
      t.datetime "password_reset_token_valid_until"
      t.boolean  "admin", default: false
      t.index ["email_address"], name: "index_users_on_email_address", length: { email_address: 8 }, using: :btree
      t.index ["uuid"], name: "index_users_on_uuid", length: { uuid: 8 }, using: :btree
    end

    create_table "webhook_events", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "webhook_id"
      t.string   "event"
      t.datetime "created_at", precision: 6
      t.index ["webhook_id"], name: "index_webhook_events_on_webhook_id", using: :btree
    end

    create_table "webhook_requests", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "server_id"
      t.integer  "webhook_id"
      t.string   "url"
      t.string   "event"
      t.string   "uuid"
      t.text     "payload", limit: 65_535
      t.integer  "attempts", default: 0
      t.datetime "retry_after", precision: 6
      t.text     "error", limit: 65_535
      t.datetime "created_at", precision: 6
    end

    create_table "webhooks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.integer  "server_id"
      t.string   "uuid"
      t.string   "name"
      t.string   "url"
      t.datetime "last_used_at"
      t.boolean  "all_events",                 default: false
      t.boolean  "enabled",                    default: true
      t.boolean  "sign",                       default: true
      t.datetime "created_at",   precision: 6
      t.datetime "updated_at",   precision: 6
      t.index ["server_id"], name: "index_webhooks_on_server_id", using: :btree
    end
  end

end
