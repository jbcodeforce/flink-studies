terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.81.0"
    }
  }
}
provider "confluent" {
  schema_registry_id            = var.schema_registry_id
  schema_registry_rest_endpoint = var.schema_registry_rest_endpoint
  schema_registry_api_key       = var.schema_registry_api_key
  schema_registry_api_secret    = var.schema_registry_api_secret
}

resource "confluent_environment" "dsp_edge_test_95a88dd4" {
  display_name = "dsp-edge-test-95a88dd4"
  stream_governance {
    package = "ADVANCED"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "lorenzo_2" {
  display_name = "lorenzo"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "dsp_usm_demo_test_67a4a4fa_3" {
  stream_governance {
    package = "ADVANCED"
  }
  display_name = "dsp-usm-demo-test-67a4a4fa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "cp_flink_demo_4" {
  display_name = "cp-flink-demo"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "test_udf_env_5" {
  display_name = "test-udf-env"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "satakshi_workspace_new_6" {
  stream_governance {
    package = "ESSENTIALS"
  }
  display_name = "Satakshi-Workspace-New"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "jeremy_playground_7" {
  stream_governance {
    package = "ESSENTIALS"
  }
  display_name = "jeremy-playground"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "justin_public_8" {
  stream_governance {
    package = "ADVANCED"
  }
  display_name = "justin-public"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "fraud_agent_env_f7d46ef7_9" {
  display_name = "fraud-agent-env-f7d46ef7"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "lorenzo_tf_10" {
  display_name = "lorenzo-tf"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "jsvoboda_11" {
  display_name = "jsvoboda"
  stream_governance {
    package = "ADVANCED"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "justin_private_12" {
  stream_governance {
    package = "ADVANCED"
  }
  display_name = "justin-private"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "staging_13" {
  stream_governance {
    package = "ESSENTIALS"
  }
  display_name = "Staging"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "osowski_sandbox_14" {
  display_name = "osowski-sandbox"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "jcustenborder_15" {
  display_name = "jcustenborder"
  stream_governance {
    package = "ADVANCED"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "lorenzo_demo_16" {
  display_name = "lorenzo-demo"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "neo_riverpay_environment_0a1e4b2b_17" {
  stream_governance {
    package = "ADVANCED"
  }
  display_name = "neo-riverpay-environment-0a1e4b2b"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "sap_datasphere_streaming_18" {
  display_name = "SAP_Datasphere_Streaming"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "satakshi_workspace_19" {
  stream_governance {
    package = "ESSENTIALS"
  }
  display_name = "Satakshi-Workspace"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "astuart_20" {
  display_name = "astuart"
  stream_governance {
    package = "ADVANCED"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "accelerator_21" {
  display_name = "accelerator"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "qi_22" {
  stream_governance {
    package = "ADVANCED"
  }
  display_name = "Qi"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "blehmann_sandbox_23" {
  display_name = "blehmann-sandbox"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "yt_history_24" {
  display_name = "yt-history"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "think_sg_2026_25" {
  display_name = "think-sg-2026"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "dominique_26" {
  stream_governance {
    package = "ESSENTIALS"
  }
  display_name = "Dominique"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "sapintegrationplayground_27" {
  display_name = "SAPIntegrationPlayground"
  stream_governance {
    package = "ESSENTIALS"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_environment" "j9r_env_28" {
  stream_governance {
    package = "ESSENTIALS"
  }
  display_name = "j9r-env"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_e0837f07" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_e0837f07"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_45d510d4_2" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_45d510d4"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "j9r_kafka_mgr_3" {
  description  = "Service account to manage 'standard' Kafka cluster"
  display_name = "j9r-kafka-mgr"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_652286_4" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-652286"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_tf_app_manager_5" {
  description  = "Manages Flink statements via Terraform (app-manager)"
  display_name = "lorenzo-tf-app-manager"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "astuart_demo_deployer_6" {
  description  = "deploy demos for astuart"
  display_name = "astuart_demo_deployer"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_yt_tf_kafka_7" {
  description  = "Terraform Kafka admin for topic and ACL management"
  display_name = "sa-yt-tf-kafka"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_6843732f_8" {
  display_name = "SA_DatagenSource_6843732f"
  description  = "Service Account for DatagenSource"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "astuartglobal_9" {
  description  = ""
  display_name = "astuartglobal"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "usm_sa_mic_10" {
  description  = "SA for USM"
  display_name = "usm_sa_mic"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "qyang_test_sa_11" {
  display_name = "qyang-test-sa"
  description  = "SA"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_659560_12" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-659560"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "taka_lineage_bridge_test_13" {
  description  = ""
  display_name = "taka-lineage-bridge-test"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_708797_14" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-708797"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_yt_counter_15" {
  description  = "YouTube history Flink counter job"
  display_name = "sa-yt-counter"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "blehmann_consumer_test_16" {
  description  = "blehmann-consumer-test"
  display_name = "blehmann-consumer-test"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_cmf_integration_2_17" {
  display_name = "lorenzo-cmf-integration-2"
  description  = "Identity used by CMF to read and write Kafka topics and Schema Registry subjects"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "bluemelon_sap_datasphere_sa_18" {
  description  = "Service Account for SAP Datasphere in BlueMelon Product Returns demo."
  display_name = "bluemelon-sap-datasphere-sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "j9r_fd_sa_19" {
  description  = "Service account to deploy Flink statements in the environment"
  display_name = "j9r-fd-sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_terraform_20" {
  description  = "Service Account for Terraform"
  display_name = "sa-terraform"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "app_manager_dev_21" {
  description  = "Service account for managing Kafka resources"
  display_name = "app-manager-dev"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_app_manager_68827884_22" {
  description  = "Service account to manage 'inventory' Kafka cluster"
  display_name = "streaming-agents-app-manager-68827884"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_763654_23" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-763654"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "justin_cenv_24" {
  description  = ""
  display_name = "justin-cenv"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_app_manager_12725c29_25" {
  description  = "Service account to manage 'inventory' Kafka cluster"
  display_name = "streaming-agents-app-manager-12725c29"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lb_uc_f862abca_sa_26" {
  display_name = "lb-uc-f862abca-sa"
  description  = "Demo service account for LineageBridge"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_yt_enricher_27" {
  description  = "YouTube history Flink enricher + classifier job"
  display_name = "sa-yt-enricher"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_954735_28" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-954735"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "fraud_agent_sa_f7d46ef7_29" {
  description  = "Manages the fraud-detection demo environment"
  display_name = "fraud-agent-sa-f7d46ef7"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "justin_usm_30" {
  description  = "justin-usm-testing"
  display_name = "justin-usm"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_082495df_31" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_082495df"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_9b752223_32" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_9b752223"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sraj_alter_table_test_33" {
  display_name = "sraj-alter-table-test"
  description  = ""
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_demo_app_manager_34" {
  description  = "App Manager to create and run Flink statements in the env 'lorenzo-demo'"
  display_name = "lorenzo-demo-app-manager"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_statement_runner_35" {
  description  = "Limited access SA for 'lorenzo' env"
  display_name = "lorenzo-statement-runner"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "taka_flink_workshop_36" {
  description  = "APIKey used by Taka to run the Flink Workshop."
  display_name = "taka-flink-workshop"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "txp_app_manager_69025db6_37" {
  display_name = "txp-app-manager-69025db6"
  description  = "Service account for managing CDC resources"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_659647_38" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-659647"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_34f433d6_39" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_34f433d6"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_platform_info_40" {
  description  = "Limited access SA for 'lorenzo' env"
  display_name = "lorenzo-platform-info"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "justin_tableflow_41" {
  description  = ""
  display_name = "justin-tableflow"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_demo_platform_manager_42" {
  description  = "Main account for TF in lorenzo-demo env"
  display_name = "lorenzo-demo-platform-manager"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "dsp_usm_demo_test_admin_43" {
  description  = "Service account for managing dsp-usm-demo-test cluster"
  display_name = "dsp-usm-demo-test-admin"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "ntwk_experiments_aws_app_manager_44" {
  description  = "Service account to manage Kafka cluster"
  display_name = "ntwk_experiments_aws_app-manager"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "test_cpi_45" {
  description  = "CPI test account`"
  display_name = "test_cpi"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_693514_46" {
  display_name = "streaming-agents-setup-sa-693514"
  description  = "Service account for streaming-agents streaming agents setup"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "kafka_sentinel_flink_47" {
  display_name = "kafka-sentinel-flink"
  description  = "Service account for Kafka Sentinel Flink SQL statements"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "tt_48" {
  description  = "test"
  display_name = "tt"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "neo_riverpay_app_manager_0a1e4b2b_49" {
  description  = "Service account for workshop Kafka cluster management"
  display_name = "neo-riverpay-app-manager-0a1e4b2b"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "healthplus_1729002926838_50" {
  display_name = "HealthPlus.1729002926838"
  description  = "SA for Health+"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_app_manager_9341f446_51" {
  description  = "Service account to manage 'inventory' Kafka cluster"
  display_name = "streaming-agents-app-manager-9341f446"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_cmf_integration_2_tf_manager_52" {
  description  = "Used by Terraform to manage Kafka ACLs for lorenzo-cmf-integration-2"
  display_name = "lorenzo-cmf-integration-2-tf-manager"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sraj_test_53" {
  description  = "srajtest"
  display_name = "sraj-test"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_658443_54" {
  display_name = "streaming-agents-setup-sa-658443"
  description  = "Service account for streaming-agents streaming agents setup"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_app_manager_fca05cf6_55" {
  display_name = "streaming-agents-app-manager-fca05cf6"
  description  = "Service account to manage 'inventory' Kafka cluster"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_743581_56" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-743581"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "justin_flink_sa_57" {
  description  = "orgadmin sa for flink"
  display_name = "justin-flink-sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "kafka_sa_58" {
  description  = "A service account for app to access kafka cluster"
  display_name = "kafka-sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_adbe2778_59" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_adbe2778"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_a9588c1f_60" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_a9588c1f"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "app_producer_61" {
  description  = "Service account to produce to 'orders' topic of 'inventory' Kafka cluster"
  display_name = "app-producer"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_639617_62" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-639617"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "taka_lineage_bridge_63" {
  display_name = "taka-lineage-bridge"
  description  = ""
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "app_connector_64" {
  display_name = "app-connector"
  description  = "Service account to manage Kafka connectors"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "xperryment_sap_datasphere_sa_65" {
  description  = "Service account to be used by SAP Datasphere data connections, with minimal RBAC required by SAP Datasphere"
  display_name = "xperryment_sap_datasphere_sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_551745_66" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-551745"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "my_service_account_3471_67" {
  description  = "Service Account for Tableflow talking to Kafka Cluster"
  display_name = "my-service-account-3471"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_769587_68" {
  display_name = "streaming-agents-setup-sa-769587"
  description  = "Service account for streaming-agents streaming agents setup"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "dsp_north_admin_69" {
  description  = "Service account for managing dsp-north cluster"
  display_name = "dsp-north-admin"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "justin_datagen_70" {
  description  = ""
  display_name = "justin-datagen"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "taka_connectors_sa_71" {
  description  = ""
  display_name = "taka-connectors-sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "justin_connect_72" {
  display_name = "justin-connect"
  description  = ""
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "dsp_usm_demo_test_cp_sr_73" {
  description  = "Service account for cp node Schema Registry forwarding to Confluent Cloud"
  display_name = "dsp-usm-demo-test-cp-sr"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_f70cc35e_74" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_f70cc35e"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "jansa_75" {
  description  = ""
  display_name = "jansa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lb_bq_dd1ce47f_sa_76" {
  description  = "Demo service account for LineageBridge"
  display_name = "lb-bq-dd1ce47f-sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_tf_platform_info_77" {
  description  = "Read-only Confluent Cloud API access for Terraform (platform-info)"
  display_name = "lorenzo-tf-platform-info"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_764510_78" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-764510"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "metricsimporterlehmann_79" {
  description  = "A test service account to import Confluent Cloud metrics into our monitoring system"
  display_name = "MetricsImporterLehmann"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_terraform_bot_80" {
  description  = "Service Account to be used by Terraform provider that invokes the Control Plane REST APIs."
  display_name = "sa-terraform-bot"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_655442_81" {
  display_name = "streaming-agents-setup-sa-655442"
  description  = "Service account for streaming-agents streaming agents setup"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_platform_manager_82" {
  description  = "Limited-access for 'lorenzo' environment"
  display_name = "lorenzo-platform-manager"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "dsp_usm_demo_test_cp_usm_83" {
  description  = "Service account for cp node USM agent (dsp-usm-demo-test)"
  display_name = "dsp-usm-demo-test-cp-usm"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_726417_84" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-726417"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sgws_cpi_85" {
  description  = "Test account for SGWS SAP Cloud Integration with limited access rights"
  display_name = "SGWS_CPI"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_552b403f_86" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_552b403f"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_332220_87" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-332220"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_app_manager_88" {
  description  = "Limited access SA for 'lorenzo' env"
  display_name = "lorenzo-app-manager"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "marqdemo_connect_89" {
  description  = ""
  display_name = "marqdemo_connect"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_eb0c9921_90" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_eb0c9921"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lb_glue_5e8113d6_sa_91" {
  display_name = "lb-glue-5e8113d6-sa"
  description  = "Demo service account for LineageBridge"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_787641_92" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-787641"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lorenzo_tf_statements_runner_93" {
  description  = "Principal that Flink statements run as (statements-runner)"
  display_name = "lorenzo-tf-statements-runner"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "j9r_flink_app_94" {
  description  = "Service account as which Flink statements run in the environment"
  display_name = "j9r-flink-app"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_147235_95" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-147235"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_8860bd24_96" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_8860bd24"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "app_manager_97" {
  description  = "Service account to manage Kafka cluster"
  display_name = "app-manager"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "qyang_demo_sa_98" {
  description  = "demo"
  display_name = "qyang-demo-sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_659374_99" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-659374"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "taka_training_sa_100" {
  description  = "Service account used by Taka during training."
  display_name = "taka-training-sa"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_326214_101" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-326214"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_167264_102" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-167264"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_yt_producer_103" {
  description  = "YouTube history Python producer"
  display_name = "sa-yt-producer"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "astuart_tf_104" {
  description  = "tf for astuar"
  display_name = "astuart_TF"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "lineage_bridge_extractor_105" {
  description  = "Auto-provisioned service account for LineageBridge extractor"
  display_name = "lineage-bridge-extractor"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "app_consumer_106" {
  description  = "Service account to consume from 'orders' topic of 'inventory' Kafka cluster"
  display_name = "app-consumer"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_693362_107" {
  description  = "Service account for streaming-agents streaming agents setup"
  display_name = "streaming-agents-setup-sa-693362"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "streaming_agents_setup_sa_078323_108" {
  display_name = "streaming-agents-setup-sa-078323"
  description  = "Service account for streaming-agents streaming agents setup"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sraj_dev_read_109" {
  description  = ""
  display_name = "sraj-dev-read"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "j9r_env_manager_110" {
  display_name = "j9r-env-manager"
  description  = "Service account to manage j9r environment"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_datagensource_d4b16eb7_111" {
  description  = "Service Account for DatagenSource"
  display_name = "SA_DatagenSource_d4b16eb7"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "dsp_north_edge_usm_112" {
  display_name = "dsp-north-edge-usm"
  description  = "Service account for edge node USM agent (dsp-north)"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "sa_yt_tf_sr_113" {
  description  = "Terraform schema registry admin"
  display_name = "sa-yt-tf-sr"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "sap_s4hana_faa_integration_cluster" {
  basic {
    max_ecku = 50
  }
  availability = "LOW"
  region       = "westus3"
  display_name = "SAP_S4HANA_FAA_Integration_Cluster"
  environment {
    id = "env-mzpz7x"
  }
  cloud               = "AZURE"
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "bluemelon_returns_demo_2" {
  display_name = "BlueMelon_Returns_Demo"
  region       = "europe-west3"
  environment {
    id = "env-xx8qkq"
  }
  basic {
    max_ecku = 50
  }
  deletion_protection = false
  availability        = "LOW"
  cloud               = "GCP"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "teladoc_3" {
  region = "us-east-2"
  basic {
    max_ecku = 50
  }
  cloud = "AWS"
  environment {
    id = "env-30d332"
  }
  availability        = "LOW"
  deletion_protection = false
  display_name        = "teladoc"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "azure_4" {
  standard {
    max_ecku = 10
  }
  availability = "LOW"
  display_name = "azure"
  cloud        = "AZURE"
  region       = "westeurope"
  environment {
    id = "env-9325m7"
  }
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "demo_5" {
  availability        = "LOW"
  deletion_protection = false
  region              = "ap-southeast-1"
  standard {
    max_ecku = 10
  }
  environment {
    id = "env-wkq70w"
  }
  cloud        = "AWS"
  display_name = "demo"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_0_6" {
  deletion_protection = false
  environment {
    id = "env-yw18do"
  }
  cloud        = "GCP"
  availability = "LOW"
  standard {
    max_ecku = 10
  }
  region       = "us-central1"
  display_name = "cluster_0"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "jans_aws_frankfurt_7" {
  cloud        = "AWS"
  region       = "eu-central-1"
  availability = "LOW"
  basic {
    max_ecku = 50
  }
  display_name        = "jans_aws_frankfurt"
  deletion_protection = false
  environment {
    id = "env-6wzjxq"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_0_8" {
  environment {
    id = "env-nx1696"
  }
  region = "us-east-2"
  basic {
    max_ecku = 50
  }
  cloud               = "AWS"
  deletion_protection = false
  availability        = "LOW"
  display_name        = "cluster_0"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_0_9" {
  environment {
    id = "env-20q1my"
  }
  display_name = "cluster_0"
  region       = "us-east-2"
  availability = "LOW"
  basic {
    max_ecku = 50
  }
  deletion_protection = false
  cloud               = "AWS"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "j9r_kafka_10" {
  display_name        = "j9r-kafka"
  availability        = "SINGLE_ZONE"
  cloud               = "AWS"
  deletion_protection = false
  region              = "us-west-2"
  standard {
    max_ecku = 10
  }
  environment {
    id = "env-yk3jm6"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "justin_public_11" {
  environment {
    id = "env-wkq70w"
  }
  availability        = "LOW"
  deletion_protection = false
  standard {
    max_ecku = 10
  }
  cloud        = "AWS"
  display_name = "justin-public"
  region       = "ap-southeast-1"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "my_second_cluster_12" {
  cloud = "AWS"
  environment {
    id = "env-06r6q2"
  }
  deletion_protection = false
  region              = "eu-west-1"
  standard {
    max_ecku = 10
  }
  availability = "HIGH"
  display_name = "my_second_cluster"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "shipments_cluster_13" {
  environment {
    id = "env-16qnn5"
  }
  standard {
    max_ecku = 10
  }
  cloud               = "AWS"
  region              = "ap-southeast-1"
  availability        = "LOW"
  deletion_protection = false
  display_name        = "shipments-cluster"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "swiggy_14" {
  region = "us-east-2"
  basic {
    max_ecku = 50
  }
  deletion_protection = false
  environment {
    id = "env-30d332"
  }
  display_name = "swiggy"
  availability = "LOW"
  cloud        = "AWS"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "dkptest2_15" {
  availability        = "LOW"
  display_name        = "dkptest2"
  deletion_protection = false
  basic {
    max_ecku = 50
  }
  region = "ap-south-1"
  cloud  = "AWS"
  environment {
    id = "env-20q1my"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_1_16" {
  region = "ap-southeast-1"
  environment {
    id = "env-20q1my"
  }
  availability = "LOW"
  basic {
    max_ecku = 50
  }
  cloud               = "AWS"
  display_name        = "cluster_1"
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "dsp_north_17" {
  environment {
    id = "env-n632jv"
  }
  deletion_protection = false
  region              = "eu-west-1"
  availability        = "MULTI_ZONE"
  display_name        = "dsp-north"
  cloud               = "AWS"
  enterprise {
    max_ecku = 32
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "yt_kafka_18" {
  basic {
    max_ecku = 50
  }
  cloud        = "AWS"
  display_name = "yt-kafka"
  environment {
    id = "env-vwr0dp"
  }
  availability        = "SINGLE_ZONE"
  region              = "us-east-1"
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_0_19" {
  availability = "LOW"
  basic {
    max_ecku = 50
  }
  region              = "ap-southeast-1"
  deletion_protection = false
  environment {
    id = "env-xwg50g"
  }
  cloud        = "AWS"
  display_name = "cluster_0"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "atg_justin_private_enterprise_20" {
  cloud               = "AWS"
  deletion_protection = false
  display_name        = "atg-justin-private-enterprise"
  enterprise {
    max_ecku = 1
  }
  environment {
    id = "env-wjzw95"
  }
  region       = "ap-southeast-1"
  availability = "LOW"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "dkp_21" {
  environment {
    id = "env-20q1my"
  }
  availability = "LOW"
  basic {
    max_ecku = 50
  }
  display_name        = "DKP"
  cloud               = "AWS"
  deletion_protection = false
  region              = "ap-south-1"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cred_22" {
  availability = "LOW"
  basic {
    max_ecku = 50
  }
  display_name = "cred"
  environment {
    id = "env-20q1my"
  }
  region              = "ap-south-1"
  deletion_protection = false
  cloud               = "AWS"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_2_23" {
  availability = "LOW"
  region       = "eu-west-2"
  standard {
    max_ecku = 10
  }
  cloud               = "AWS"
  display_name        = "cluster_2"
  deletion_protection = false
  environment {
    id = "env-9325m7"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "demo_cluster_1_24" {
  deletion_protection = false
  availability        = "LOW"
  environment {
    id = "env-r6pvk7"
  }
  cloud = "AWS"
  standard {
    max_ecku = 10
  }
  display_name = "demo_cluster_1"
  region       = "eu-west-1"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "my_cluster_25" {
  availability = "LOW"
  cloud        = "AWS"
  display_name = "my_cluster"
  environment {
    id = "env-06r6q2"
  }
  region = "eu-west-1"
  standard {
    max_ecku = 10
  }
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "dsp_usm_demo_test_26" {
  environment {
    id = "env-px0j3o"
  }
  region              = "eu-west-1"
  availability        = "MULTI_ZONE"
  deletion_protection = false
  display_name        = "dsp-usm-demo-test"
  cloud               = "AWS"
  enterprise {
    max_ecku = 32
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "neo_riverpay_cluster_0a1e4b2b_27" {
  environment {
    id = "env-mg0917"
  }
  display_name = "neo-riverpay-cluster-0a1e4b2b"
  standard {
    max_ecku = 10
  }
  deletion_protection = false
  availability        = "SINGLE_ZONE"
  region              = "us-east-1"
  cloud               = "AWS"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_2_28" {
  cloud        = "AZURE"
  display_name = "cluster_2"
  environment {
    id = "env-6wzjxq"
  }
  standard {
    max_ecku = 10
  }
  region              = "uaenorth"
  availability        = "HIGH"
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_0_29" {
  availability = "LOW"
  basic {
    max_ecku = 50
  }
  region       = "us-east-2"
  display_name = "cluster_0"
  environment {
    id = "env-2y8vz1"
  }
  cloud               = "AWS"
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "dkp2_30" {
  deletion_protection = false
  availability        = "LOW"
  cloud               = "AWS"
  display_name        = "dkp2"
  region              = "us-east-1"
  basic {
    max_ecku = 50
  }
  environment {
    id = "env-30d332"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "inventory_31" {
  environment {
    id = "env-6z6xwq"
  }
  availability = "SINGLE_ZONE"
  network {
    id = "n-g0d4em"
  }
  cloud = "AWS"
  dedicated {
    encryption_key = ""
    zones          = ["use2-az1"]
    cku            = 1
  }
  deletion_protection = false
  region              = "us-east-2"
  display_name        = "inventory"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "bharatpe_32" {
  availability = "LOW"
  environment {
    id = "env-30d332"
  }
  deletion_protection = false
  display_name        = "bharatpe"
  region              = "ap-southeast-1"
  basic {
    max_ecku = 50
  }
  cloud = "AWS"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "jans_azure_33" {
  region = "germanywestcentral"
  standard {
    max_ecku = 10
  }
  display_name = "jans_azure"
  environment {
    id = "env-6wzjxq"
  }
  availability        = "HIGH"
  deletion_protection = false
  cloud               = "AZURE"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "sap_s4hana_onibex_oneconnect_34" {
  standard {
    max_ecku = 10
  }
  display_name = "sap_s4hana_onibex_oneconnect"
  environment {
    id = "env-mzpz7x"
  }
  availability        = "LOW"
  region              = "eu-central-1"
  cloud               = "AWS"
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "sap_datasphere_xperryment_35" {
  environment {
    id = "env-xx8qkq"
  }
  availability        = "LOW"
  deletion_protection = false
  display_name        = "SAP_Datasphere_Xperryment"
  cloud               = "AWS"
  standard {
    max_ecku = 10
  }
  region = "eu-central-1"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_1_36" {
  display_name = "cluster_1"
  availability = "LOW"
  environment {
    id = "env-9325m7"
  }
  basic {
    max_ecku = 50
  }
  cloud               = "AZURE"
  region              = "uksouth"
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_0_37" {
  cloud = "GCP"
  basic {
    max_ecku = 50
  }
  availability = "LOW"
  region       = "us-central1"
  display_name = "cluster_0"
  environment {
    id = "env-7dzogo"
  }
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "gcp_us_central1_38" {
  availability = "LOW"
  display_name = "gcp-us-central1"
  region       = "us-central1"
  environment {
    id = "env-j7o32w"
  }
  cloud = "GCP"
  standard {
    max_ecku = 10
  }
  deletion_protection = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "fraud_agent_cluster_f7d46ef7_39" {
  availability        = "SINGLE_ZONE"
  display_name        = "fraud-agent-cluster-f7d46ef7"
  region              = "us-east-1"
  deletion_protection = false
  cloud               = "AWS"
  standard {
    max_ecku = 10
  }
  environment {
    id = "env-ovw3kj"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_4_40" {
  deletion_protection = false
  cloud               = "AWS"
  availability        = "HIGH"
  standard {
    max_ecku = 10
  }
  environment {
    id = "env-20q1my"
  }
  region       = "ap-south-1"
  display_name = "cluster_4"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "snow_41" {
  region              = "us-west-2"
  cloud               = "AWS"
  display_name        = "SNOW"
  deletion_protection = false
  environment {
    id = "env-9325m7"
  }
  availability = "LOW"
  basic {
    max_ecku = 50
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "azure_cluster_42" {
  deletion_protection = false
  environment {
    id = "env-q6r1wp"
  }
  standard {
    max_ecku = 10
  }
  region       = "eastus2"
  cloud        = "AZURE"
  display_name = "azure-cluster"
  availability = "LOW"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "sandbox_43" {
  display_name = "sandbox"
  environment {
    id = "env-7d27kp"
  }
  standard {
    max_ecku = 10
  }
  cloud               = "AWS"
  region              = "us-east-1"
  deletion_protection = false
  availability        = "HIGH"
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "cluster_0_44" {
  deletion_protection = false
  display_name        = "cluster_0"
  cloud               = "AWS"
  environment {
    id = "env-yw1927"
  }
  standard {
    max_ecku = 10
  }
  availability = "HIGH"
  region       = "eu-west-1"
  lifecycle {
    prevent_destroy = true
  }
}

