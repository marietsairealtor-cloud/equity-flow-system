$ErrorActionPreference = "Stop"

git fetch origin main | Out-Null
$base = "origin/main"

function Norm([string]$p){
  return ($p.Trim() -replace "\\","/").TrimStart("./")
}

function GlobToRegex([string]$glob){
  $g = Norm $glob
  $g = [Regex]::Escape($g)
  # ** => .*
  $g = $g -replace "\\\*\\\*",".*"
  # * => [^/]* (single segment)
  $g = $g -replace "\\\*","[^/]*"
  return "^" + $g + "$"
}

function IsRobotOwned([string]$p, $patterns){
  $pp = Norm $p
  foreach($pat in $patterns){
    $rx = GlobToRegex $pat
    if($pp -match $rx){ return $true }
    # also allow prefix-match for "root/**" style paths
    $root = (Norm $pat) -replace "/\*\*.*$",""
    if($root -and $pp.StartsWith($root + "/")){ return $true }
    if($root -and $pp -eq $root){ return $true }
  }
  return $false
}

function ExceptionMatch([string]$p){
  $pp = Norm $p
  if($pp -eq "docs/proofs/manifest.json"){ return "ALLOW:manifest.json" }
  if($pp -match "^docs/proofs/2\.17\.4_parser_fixture_check_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.4 proof log" }
  if($pp -match "^docs/proofs/2\.16\.10_robot_owned_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.16.10 proof log" }
  if($pp -match "^docs/proofs/2\.16\.11_governance_change_template_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.16.11 proof log" }
  if($pp -match "^docs/proofs/2\.17\.1_normalize_sweep_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.1 proof log" }
  if($pp -match "^docs/proofs/2\.17\.1A_proof_finalize_arg_hardening_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.1A proof log" }
if($pp -match "^docs/proofs/2\.17\.2_encoding_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.2 proof log" }
  if($pp -eq "docs/proofs/_archive/2.5_truth_bootstrap_20260208_231039Z.log"){ return "ALLOW:archive 2.5 repaired log" }
  if($pp -eq "docs/proofs/2.5_truth_bootstrap_20260208_231412Z.log"){ return "ALLOW:2.5 repaired log" }
  if($pp -eq "docs/proofs/2.6_required_checks_contract_20260208_232749Z.log"){ return "ALLOW:2.6 repaired log" }
  if($pp -eq "docs/proofs/2.7_docs_only_ci_skip_20260208_234320Z.log"){ return "ALLOW:2.7 repaired log" }
  if($pp -eq "docs/proofs/2.16.2A_hash_authority_contract_20260211_161401Z.log"){ return "ALLOW:2.16.2A repaired log" }
  if($pp -match "^docs/proofs/2\.17\.3_path_leak_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.17.3 proof log" }
  if($pp -eq "docs/proofs/4.1_cloud_baseline_20260219_144802.md"){ return "ALLOW:4.1 proof log" }
  if($pp -match "^docs/proofs/4\.2_toolchain_versions_supabase_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.2 proof log" }
  if($pp -match "^docs/proofs/4\.2a_command_smoke_db_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.2A proof log" }
  if($pp -match "^docs/proofs/3\.1_automation_contract_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.1 proof log" }
  if($pp -match "^docs/proofs/3\.2_ship_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.2 proof log" }
  if($pp -match "^docs/proofs/3\.3_handoff_commit_push_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.3 proof log" }
  if($pp -match "^docs/proofs/3\.4_docs_push_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.4 proof log" }
  if($pp -match "^docs/proofs/3\.5_qa_requirements_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.5 proof log" }
  if($pp -match "^docs/proofs/3\.6_robot_owned_publish_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.6 proof log" }
  if($pp -match "^docs/proofs/3\.7_qa_verify_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.7 proof log" }
  if($pp -match "^docs/proofs/3\.8_handoff_idempotency_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.8 proof log" }
  if($pp -match "^docs/proofs/3\.9\.1_deferred_proof_registry_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.1 proof log" }
  if($pp -match "^docs/proofs/3\.9\.2_governance_path_coverage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.2 proof log" }
  if($pp -match "^docs/proofs/3\.9\.3_qa_scope_coverage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.3 proof log" }
  if($pp -match "^docs/proofs/3\.9\.4_job_graph_ordering_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.4 proof log" }
  if($pp -match "^docs/proofs/3\.9\.5_proof_secret_scan_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.5 proof log" }
  if($pp -match "^docs/proofs/4\.3_cloud_baseline_inventory_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.3 proof log" }
  if($pp -match "^docs/proofs/4\.4_anon_privilege_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.4 proof log" }
  if($pp -eq "docs/truth/ci_execution_surface.json"){ return "ALLOW:4.6 ci_execution_surface.json machine-derived" }
  if($pp -eq "docs/truth/write_path_registry.json"){ return "ALLOW:6.6 write_path_registry.json machine-derived" }
  if($pp -match "^docs/proofs/4\.5_tenancy_resolution_enforcement_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.5 proof log" }
  if($pp -match "^docs/proofs/4\.6_two_tier_execution_contract_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.6 proof log" }
  if($pp -match "^docs/proofs/4\.7_tier1_surface_normalization_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.7 proof log" }
  if($pp -match "^docs/proofs/5\.0_required_gates_inventory_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.0 proof log" }
  if($pp -match "^docs/proofs/5\.1_migration_rls_colocation_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.1 proof log" }
  if($pp -match "^docs/proofs/5\.3_migration_schema_coupling_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.3 proof log" }
  if($pp -match "^docs/proofs/6\.1_greenfield_baseline_migrations_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.1 proof log" }
  if($pp -match "^docs/proofs/6\.1A_handoff_preconditions_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.1A proof log" }
if($pp -match "^docs/proofs/6\.2_definer_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.2 proof log" }
if($pp -match "^docs/proofs/6\.3_tenant_integrity_suite_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.3 proof log" }
if($pp -match "^docs/proofs/6\.3A_unregistered_table_access_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.3A proof log" }
if($pp -match "^docs/proofs/6\.4_rls_structural_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.4 proof log" }
if($pp -match "^docs/proofs/6\.5_blocked_identifiers_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.5 proof log" }
if($pp -match "^docs/proofs/6\.6_product_core_tables_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.6 proof log" }
if($pp -match "^docs/proofs/6\.7_share_link_surface_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.7 proof log" }
  if($pp -match "^docs/proofs/6\.8_seat_role_model_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.8 proof log" }
  if($pp -match "^docs/proofs/6\.9_foundation_surface_ready_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.9 proof log" }
  if($pp -match "^docs/proofs/6\.10_activity_log_append_only_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.10 proof log" }
  if($pp -match "^docs/proofs/6\.11_role_guard_helper_\d{8}T\d{6}Z\.log$"){ return "ALLOW:6.11 proof log" }
  if($pp -match "^docs/proofs/7\.1_schema_snapshot_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.1 proof log" }
  if($pp -match "^docs/proofs/7\.1A_preflight_hook_wiring_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.1A proof log" }
  if($pp -match "^docs/proofs/7\.4_entitlement_truth_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.4 proof log" }
  if($pp -match "^docs/proofs/7\.2_privilege_truth_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.2 proof log" }
  if($pp -match "^docs/proofs/7\.3_contracts_policy_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.3 proof log" }
  if($pp -match "^docs/proofs/7\.5_product_rls_negative_suite_\d{8}T\d{6}Z\.(log|md)$"){ return "ALLOW:7.5 proof log" }
  if($pp -match "^docs/proofs/7\.6_calc_version_protocol_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.6 proof log" }
  if($pp -match "^docs/proofs/7\.7_studio_mutation_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.7 proof log" }
  if($pp -match "^docs/proofs/7\.8_role_enforcement_rpc_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.8 proof log" }
  if($pp -match "^docs/proofs/7\.9_tenant_context_integrity_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.9 proof log" }
  if($pp -match "^docs/proofs/8\.0\.5_pgtap_conversion_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.0.5 proof log" }
  if($pp -match "^docs/proofs/8\.1_clean_room_replay_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.1 proof log" }
  if($pp -match "^docs/proofs/8\.6_share_token_revocation_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.6 proof log" }
  if($pp -match "^docs/proofs/8\.7_share_token_usage_logging_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.7 proof log" }
  if($pp -match "^docs/proofs/8\.8_share_token_secure_generation_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.8 proof log" }
  if($pp -match "^docs/proofs/8\.9_share_token_expiration_invariant_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.9 proof log" }
  if($pp -match "^docs/proofs/8\.10_share_token_scope_enforcement_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.10 proof log" }
  if($pp -match "^docs/proofs/9\.1_surface_truth_schema_\d{8}T\d{6}Z\.log$"){ return "ALLOW:9.1 proof log" }
  if($pp -match "^docs/proofs/9\.2_surface_truth_\d{8}T\d{6}Z\.log$"){ return "ALLOW:9.2 proof log" }
  if($pp -match "^docs/proofs/9\.3_reload_contract_\d{8}T\d{6}Z\.md$"){ return "ALLOW:9.3 proof doc" }
  if($pp -match "^docs/proofs/9\.4_token_format_validation_\d{8}T\d{6}Z\.log$"){ return "ALLOW:9.4 proof log" }
  if($pp -match "^docs/proofs/9\.5_token_cardinality_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:9.5 proof log" }
  if($pp -match "^docs/proofs/9\.6_data_surface_truth_\d{8}T\d{6}Z\.log$"){ return "ALLOW:9.6 proof log" }
  if($pp -match "^docs/proofs/9\.7_token_lifetime_invariant_\d{8}T\d{6}Z\.md$"){ return "ALLOW:9.7 proof doc" }
  if($pp -match "^docs/proofs/10\.1_weweb_smoke_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.1 proof doc" }
  if($pp -match "^docs/proofs/10\.2_weweb_drift_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.2 proof log" }
  if($pp -match "^docs/proofs/10\.3_rpc_response_schema_contracts_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.3 proof doc" }
  if($pp -match "^docs/proofs/10\.4_rpc_response_contract_tests_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.4 proof log" }
  if($pp -match "^docs/proofs/10\.5_rpc_error_contract_tests_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.5 proof log" }
  if($pp -match "^docs/proofs/10\.6_rpc_contract_registry_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.6 proof log" }
  if($pp -match "^docs/proofs/10\.7_gate_promotion_registry_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.7 proof log" }
  if($pp -match "^docs/proofs/10\.7\.1_legacy_gate_promotion_retrofit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.7.1 proof log" }
  if($pp -match "^docs/proofs/10\.7_gate_promotion_registry_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.7 proof log" }
  if($pp -match "^docs/proofs/10\.7\.1_legacy_gate_promotion_retrofit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.7.1 proof log" }
  if($pp -match "^docs/proofs/10\.8_authenticated_shell_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8 proof doc" }
  if($pp -match "^docs/proofs/10\.8\.1_slug_system_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.1 proof log" }
  if($pp -match "^docs/proofs/10\.8\.1A_subscriptions_table_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.1A proof log" }
  if($pp -match "^docs/proofs/10\.8\.2_entitlements_extension_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.2 proof log" }
  if($pp -match "^docs/proofs/10\.8\.3_reminder_engine_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.3 proof log" }
  if($pp -match "^docs/proofs/10\.8\.3A_migration_test_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.3A proof log" }
  if($pp -match "^docs/proofs/10\.8\.3B_migration_test_remediation_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.3B proof log" }
  if($pp -match "^docs/proofs/10\.8\.3C_design_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.3C proof log" }
  if($pp -match "^docs/proofs/10\.8\.4_deal_health_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.4 proof log" }
  if($pp -match "^docs/proofs/10\.8\.5_tc_data_model_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.5 proof log" }
  if($pp -match "^docs/proofs/10\.8\.6_farm_areas_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.6 proof log" }
  if($pp -match "^docs/proofs/10\.8\.6A_automation_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.6A proof log" }
  if($pp -match "^docs/proofs/10\.8\.7_tc_storage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.7 proof log" }
  if($pp -match "^docs/proofs/10\.8\.7A_deal_photos_storage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.7A proof log" }
  if($pp -match "^docs/proofs/10\.8\.7C_tenant_context_parity_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.7C proof log" }
  if($pp -match "^docs/proofs/10\.8\.7D_accept_invite_tenant_sync_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.7D proof log" }
  if($pp -match "^docs/proofs/10\.8\.7E_accept_pending_invites_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.7E proof log" }
  if($pp -match "^docs/proofs/10\.8\.7F_pending_invite_invariants_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.7F proof log" }
  if($pp -match "^docs/proofs/10\.8\.8_auth_page_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.8 proof log" }
  if($pp -match "^docs/proofs/10\.8\.7B_tenant_invites_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.7B proof log" }
  if($pp -match "^docs/proofs/10\.8\.8A_create_workspace_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.8A proof log" }
  if($pp -match "^docs/proofs/10\.8\.8B_set_tenant_slug_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.8B proof log" }
  if($pp -match "^docs/proofs/10\.8\.8C_stripe_billing_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.8C proof log" }
  if($pp -match "^docs/proofs/10\.8\.8D_check_slug_access_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.8D proof log" }
  if($pp -match "^docs/proofs/10\.8\.9_onboarding_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.9 proof log" }
  if($pp -match "^docs/proofs/10\.8\.10_today_view_shell_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.10 proof log" }
  if($pp -match "^docs/proofs/10\.8\.11A_list_user_tenants_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11A proof log" }
  if($pp -match "^docs/proofs/10\.8\.11B_set_current_tenant_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11B proof log" }
  if($pp -match "^docs/proofs/10\.8\.11C_workspace_switcher_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11C proof log" }
  if($pp -match "^docs/proofs/10\.8\.11D_profile_settings_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11D proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11E_workspace_settings_read_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11E proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11E1_workspace_slug_invariant_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11E1 proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11F_workspace_settings_general_rpcs_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11F proof log" }
  if($pp -match "^docs/proofs/10\.8\.11G_workspace_members_rpcs_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11G proof log" }
  if($pp -match "^docs/proofs/10\.8\.11H_workspace_farm_areas_rpcs_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11H proof log" }
  if($pp -match "^docs/proofs/10\.8\.11I_workspace_settings_ui_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11I proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11I1_invite_email_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11I1 proof log" }
  if($pp -match "^docs/proofs/10\.8\.11I2_workspace_settings_read_fix_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11I2 proof log" }
  if($pp -match "^docs/proofs/10\.8\.11I3_pending_invites_rpc_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11I3 proof log" }
  if($pp -match "^docs/proofs/10\.8\.11I4_pending_invites_ui_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11I4 proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11I5_seat_billing_sync_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11I5 proof log" }
  if($pp -match "^docs/proofs/10\.8\.11I6_billing_seat_ui_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11I6 proof doc" }  
  if($pp -match "^docs/proofs/10\.8\.11I7_reinvite_email_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11I7 proof log" }
  if($pp -match "^docs/proofs/10\.8\.11I8_list_user_tenants_workspace_name_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11I8 proof log" }
  if($pp -match "^docs/proofs/10\.8\.11I9_workspace_switcher_name_ui_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11I9 proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11J_update_display_name_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11J proof log" }
  if($pp -match "^docs/proofs/10\.8\.11K_subscription_status_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11K proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11L_renew_now_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11L proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11M_entitlement_access_retention_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11M proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11N_expired_write_lock_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11N proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11N1_write_lock_coverage_gate_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11N1 proof log" }
  if($pp -match "^docs/proofs/10\.8\.11O_retention_archive_lifecycle_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11O proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11O1_archived_workspace_restore_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11O1 proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11O2_entitlement_archived_state_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11O2 proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11O3_archived_workspace_restore_targeting_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11O3 proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11P_expired_archived_workspace_ui_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.11P proof doc" }
  if($pp -match "^docs/proofs/10\.8\.11Q_storage_drift_guard_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11Q proof log" }
  if($pp -match "^docs/proofs/10\.8\.11R_node24_runtime_compatibility_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.8.11R proof log" }
  if($pp -match "^docs/proofs/10\.8\.12_free_trial_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.12 proof doc" }
  if($pp -match "^docs/proofs/10\.8\.12A_trial_eligibility_ui_surface_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.12A proof doc" }
  if($pp -match "^docs/proofs/10\.8\.13_subscription_lifecycle_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.8.13 proof doc" }
  if($pp -match "^docs/proofs/10\.9_mao_calculator_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.9 proof doc (BUILD_ROUTE 10.9)" }
  if($pp -match "^docs/proofs/10\.10_mao_golden_path_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.10 proof doc (BUILD_ROUTE 10.10)" }
  if($pp -match "^docs/proofs/10\.11_acquisition_ui_\d{8}T\d{6}Z\.md$"){ return "ALLOW:10.11 proof doc (BUILD_ROUTE 10.11)" }
  if($pp -match "^docs/proofs/10\.11A_acquisition_backend_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.11A proof (BUILD_ROUTE 10.11A)" }
  if($pp -match "^docs/proofs/10\.11A1_deal_notes_activity_log_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.11A1 proof log" }
  if($pp -match "^docs/proofs/10\.11A2_deal_edit_write_paths_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.11A2 proof log" }
  if($pp -match "^docs/proofs/10\.11A3_acq_deal_detail_read_corrections_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.11A3 proof log" }
  if($pp -match "^docs/proofs/10\.11A4_acq_kpi_date_range_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.11A4 proof log" }
  if($pp -match "^docs/proofs/10\.11A5_deal_properties_schema_normalization_\d{8}T\d{6}Z\.log$"){ return "ALLOW:10.11A5 proof log" }
  if($pp -eq "docs/truth/deal_health_thresholds.json"){ return "ALLOW:10.8.4 deal health thresholds truth file" }
  if($pp -eq "docs/truth/rpc_schemas/list_deals_v1.json"){ return "ALLOW:10.8.4 list_deals_v1 schema update" }
  if($pp -eq "docs/truth/surface_truth.json"){ return "ALLOW:9.1 surface truth capture" }
  if($pp -match "^docs/proofs/8\.2_clean_room_tests_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.2 proof log" }
  if($pp -match "^docs/proofs/8\.3_cloud_migration_parity_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.3 proof log" }
  if($pp -eq "docs/truth/cloud_migration_parity.json"){ return "ALLOW:10.8.6A cloud_migration_parity.json (robot-owned via sync_truth_registries)" }
  if($pp -eq "docs/truth/definer_allowlist.json"){ return "ALLOW:10.8.6A definer_allowlist.json (robot-owned via sync_truth_registries)" }
  if($pp -eq "docs/truth/execute_allowlist.json"){ return "ALLOW:10.8.6A execute_allowlist.json (robot-owned via sync_truth_registries)" }
  if($pp -eq "docs/truth/tenant_table_selector.json"){ return "ALLOW:10.8.6A tenant_table_selector.json (robot-owned via sync_truth_registries)" }
  if($pp -match "^docs/proofs/8\.4_share_token_hash_at_rest_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.4 proof log" }
  if($pp -match "^docs/proofs/8\.5_share_surface_abuse_controls_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.5 proof log" }
  if($pp -match "^docs/proofs/7\.10_tenant_role_ordering_invariant_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.10 proof log" }
  if($pp -match "^docs/proofs/7\.11_studio_drift_sla_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.11 proof log" }
  if($pp -match "^docs/proofs/7\.11A_cloud_schema_drift_gate_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.11A proof log" }
  if($pp -match "^docs/proofs/7\.12_rpc_mapping_contract_\d{8}T\d{6}Z\.log$"){ return "ALLOW:7.12 proof log" }
  if($pp -match "^docs/proofs/8\.0_ci_db_infrastructure_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.0 proof log" }
  if($pp -match "^docs/proofs/8\.0\.1_clean_room_replay_conversion_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.0.1 proof log" }
  if($pp -match "^docs/proofs/8\.0\.2_schema_drift_conversion_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.0.2 proof log" }
  if($pp -match "^docs/proofs/8\.0\.3_handoff_idempotency_conversion_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.0.3 proof log" }
  if($pp -match "^docs/proofs/8\.0\.4_definer_safety_audit_conversion_\d{8}T\d{6}Z\.log$"){ return "ALLOW:8.0.4 proof log" }
  if($pp -match "^docs/truth/calc_version_registry\.json$"){ return "ALLOW:calc_version_registry.json (PR-updated truth file)" }
  if($pp -match "^docs/proofs/2\.16\.5C_foundation_invariants_suite_\d{8}T\d{6}Z\.log$"){ return "ALLOW:2.16.5C proof log" }
  if($pp -match "^docs/proofs/5\.0_required_gates_inventory_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.0 proof log" }
  if($pp -match "^docs/proofs/5\.1_migration_rls_colocation_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.1 proof log" }
  if($pp -match "^docs/proofs/5\.3_migration_schema_coupling_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.3 proof log" }
  if($pp -match "^docs/truth/qa_claim\.json$"){ return "ALLOW:qa_claim.json" }
  if($pp -match "^docs/truth/qa_scope_map\.json$"){ return "ALLOW:qa_scope_map.json" }
  if($pp -match "^docs/proofs/3\.7_qa_verify_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.7 proof log" }
  if($pp -match "^docs/proofs/3\.8_handoff_idempotency_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.8 proof log" }
  if($pp -match "^docs/proofs/3\.9\.1_deferred_proof_registry_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.1 proof log" }
  if($pp -match "^docs/proofs/3\.9\.2_governance_path_coverage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.2 proof log" }
  if($pp -match "^docs/proofs/3\.9\.3_qa_scope_coverage_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.3 proof log" }
  if($pp -match "^docs/proofs/3\.9\.4_job_graph_ordering_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.4 proof log" }
  if($pp -match "^docs/proofs/3\.9\.5_proof_secret_scan_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.9.5 proof log" }
  if($pp -match "^docs/proofs/4\.3_cloud_baseline_inventory_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.3 proof log" }
  if($pp -match "^docs/proofs/4\.4_anon_privilege_audit_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.4 proof log" }
  if($pp -eq "docs/truth/ci_execution_surface.json"){ return "ALLOW:4.6 ci_execution_surface.json machine-derived" }
  if($pp -eq "docs/truth/write_path_registry.json"){ return "ALLOW:6.6 write_path_registry.json machine-derived" }
  if($pp -match "^docs/proofs/4\.5_tenancy_resolution_enforcement_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.5 proof log" }
  if($pp -match "^docs/proofs/4\.6_two_tier_execution_contract_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.6 proof log" }
  if($pp -match "^docs/proofs/4\.7_tier1_surface_normalization_\d{8}T\d{6}Z\.log$"){ return "ALLOW:4.7 proof log" }
  if($pp -match "^docs/proofs/5\.0_required_gates_inventory_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.0 proof log" }
  if($pp -match "^docs/proofs/5\.1_migration_rls_colocation_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.1 proof log" }
  if($pp -match "^docs/proofs/5\.3_migration_schema_coupling_\d{8}T\d{6}Z\.log$"){ return "ALLOW:5.3 proof log" }
  if($pp -match "^docs/proofs/qa_claim\.json$"){ return "ALLOW:qa_claim.json" }
  if($pp -match "^docs/truth/qa_scope_map\.json$"){ return "ALLOW:qa_scope_map.json" }
  if($pp -match "^docs/proofs/3\.5_qa_requirements_\d{8}T\d{6}Z\.log$"){ return "ALLOW:3.5 proof log" }
  if($pp -eq "docs/handoff_latest.txt"){ return "ALLOW:handoff artifact" }
  if($pp -eq "generated/contracts.snapshot.json"){ return "ALLOW:handoff artifact" }
  if($pp -eq "generated/schema.sql"){ return "ALLOW:handoff artifact" }
  if($pp -eq "generated/schema_ci.sql"){ return "ALLOW:generated schema CI artifact" }

  # Allowed historical proof repairs (SOP §3.2) — explicit file allowlist
  if($pp -eq "docs/proofs/1.3_denylist_20260208_002421.log"){ return "ALLOW:1.3 repaired log" }
  if($pp -eq "docs/proofs/2.15_governance_change_20260210_001959Z.log"){ return "ALLOW:2.15 repaired log" }
  if($pp -eq "docs/proofs/2.17.1A_proof_finalize_arg_hardening_20260218T175242Z.log"){ return "ALLOW:2.17.1A repaired log" }
  if($pp -eq "docs/proofs/2.17.2_encoding_audit_20260218T214411Z.log"){ return "ALLOW:2.17.2 repaired log" }

  if($pp -eq "docs/proofs/_archive/1.3_ci_local_20260208_001355.log"){ return "ALLOW:archive 1.3 repaired log" }
  if($pp -eq "docs/proofs/_archive/1.3_denylist_20260208_001230.log"){ return "ALLOW:archive 1.3 repaired log" }
  if($pp -eq "docs/proofs/_archive/2.9_QA_BUNDLE_20260209_103215Z.txt"){ return "ALLOW:archive 2.9 repaired bundle" }
  return $null
}

$cfgPath = "docs/truth/robot_owned_paths.json"
if(!(Test-Path $cfgPath)){ Write-Error "MISSING: $cfgPath"; exit 1 }

$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$patterns = @($cfg.paths | ForEach-Object { "$_" }) | Where-Object { $_ }

$raw = @(git diff --name-status "$base...HEAD" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
$changed = @()
foreach($ln in $raw){
  $parts = $ln -split "`t"
  if($parts.Count -lt 2){ continue }
  $st = $parts[0]
  if($st -match "^R"){ $changed += (Norm $parts[2]); continue }
  $changed += (Norm $parts[1])
}
$changed = $changed | Sort-Object -Unique

$robot = @()
foreach($f in $changed){
  if(IsRobotOwned $f $patterns){ $robot += $f }
}

Write-Host "=== robot-owned-guard ==="
Write-Host ("BASE=" + $base)
Write-Host ("CHANGED_FILES=" + $changed.Count)
foreach($f in $changed){ Write-Host (" - " + $f) }

Write-Host "ROBOT_OWNED_CHANGED:"
if($robot.Count -eq 0){
  Write-Host " (none)"
  Write-Host "STATUS: PASS"
  exit 0
}
foreach($f in $robot){
  $ex = ExceptionMatch $f
  if($ex){
    Write-Host (" - " + $f + " :: " + $ex)
  } else {
    Write-Host (" - " + $f + " :: NO_EXCEPTION")
  }
}

$off = @()
foreach($f in $robot){
  if(-not (ExceptionMatch $f)){ $off += $f }
}

if($off.Count -gt 0){
  Write-Host "OFFENDING_PATHS:"
  foreach($f in $off){ Write-Host (" - " + $f + " :: robot-owned (no allowed exception)") }
  Write-Host "STATUS: FAIL"
  exit 1
}

Write-Host "STATUS: PASS"
exit 0



