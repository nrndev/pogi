module github.com/nrndev/pogi

go 1.27.3

require (
	charm.land/bubbletea/v2 v2.1.0
	charm.land/lipgloss/v2 v2.0.6
	cloud.google.com/go v0.123.0
	cloud.google.com/go/artifactregistry v1.27.0
	cloud.google.com/go/bigquery v1.79.0
	cloud.google.com/go/bigtable v1.58.0
	cloud.google.com/go/chronicle v1.5.0
	cloud.google.com/go/cloudquotas v1.13.0
	cloud.google.com/go/cloudsecuritycompliance v1.2.0
	cloud.google.com/go/cloudtasks v1.20.0
	cloud.google.com/go/compute v1.72.0
	cloud.google.com/go/container v1.55.0
	cloud.google.com/go/datastore v1.27.0
	cloud.google.com/go/edgecontainer v1.10.0
	cloud.google.com/go/eventarc v1.26.0
	cloud.google.com/go/firestore v1.26.0
	cloud.google.com/go/functions v1.26.0
	cloud.google.com/go/gkemulticloud v1.12.0
	cloud.google.com/go/iam v1.12.0
	cloud.google.com/go/kms v1.35.0
	cloud.google.com/go/licensemanager v1.2.0
	cloud.google.com/go/logging v1.19.0
	cloud.google.com/go/longrunning v1.2.0
	cloud.google.com/go/lustre v1.2.0
	cloud.google.com/go/managedkafka v1.2.0
	cloud.google.com/go/memorystore v1.5.0
	cloud.google.com/go/monitoring v1.30.0
	cloud.google.com/go/privilegedaccessmanager v1.2.0
	cloud.google.com/go/pubsub/v2 v2.7.0
	cloud.google.com/go/redis v1.27.0
	cloud.google.com/go/resourcemanager v1.17.0
	cloud.google.com/go/run v1.23.0
	cloud.google.com/go/scheduler v1.17.0
	cloud.google.com/go/secretmanager v1.22.0
	cloud.google.com/go/serviceusage v1.16.0
	cloud.google.com/go/spanner v1.91.0
	cloud.google.com/go/storage v1.69.0
	cloud.google.com/go/workflows v1.20.0
	firebase.google.com/go/v4 v4.22.0
	github.com/Azure/azure-sdk-for-go/sdk/azcore v1.23.3
	github.com/Azure/azure-sdk-for-go/sdk/azidentity v1.15.0
	github.com/Azure/azure-sdk-for-go/sdk/data/azappconfig v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos v1.5.0
	github.com/Azure/azure-sdk-for-go/sdk/data/aztables v1.4.1
	github.com/Azure/azure-sdk-for-go/sdk/messaging/azeventhubs/v2 v2.0.2
	github.com/Azure/azure-sdk-for-go/sdk/messaging/azservicebus v1.11.0
	github.com/Azure/azure-sdk-for-go/sdk/messaging/eventgrid/azeventgrid v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/monitor/ingestion/azlogs v1.1.0
	github.com/Azure/azure-sdk-for-go/sdk/monitor/query/azlogs v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/advisor/armadvisor v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/analysisservices/armanalysisservices v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/apimanagement/armapimanagement/v2 v2.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/appcontainers/armappcontainers/v3 v3.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/appservice/armappservice/v6 v6.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/automation/armautomation v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/avs/armavs/v2 v2.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/azurestackhci/armazurestackhci/v3 v3.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/batch/armbatch/v4 v4.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/cdn/armcdn/v3 v3.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/chaos/armchaos/v2 v2.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/cognitiveservices/armcognitiveservices/v3 v3.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/compute/armcompute/v7 v7.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/confidentialledger/armconfidentialledger v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/consumption/armconsumption/v2 v2.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerinstance/armcontainerinstance/v2 v2.4.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerregistry/armcontainerregistry v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice/v6 v6.6.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservicefleet/armcontainerservicefleet/v3 v3.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/cosmos/armcosmos/v3 v3.4.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/costmanagement/armcostmanagement/v3 v3.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/dashboard/armdashboard/v2 v2.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/databricks/armdatabricks/v2 v2.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/datafactory/armdatafactory/v11 v11.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/datashare/armdatashare v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/desktopvirtualization/armdesktopvirtualization/v2 v2.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/devcenter/armdevcenter/v2 v2.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/deviceprovisioningservices/armdeviceprovisioningservices v1.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/devopsinfrastructure/armdevopsinfrastructure v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/devtestlabs/armdevtestlabs v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/digitaltwins/armdigitaltwins v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/dns/armdns v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/domainservices/armdomainservices v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/elasticsan/armelasticsan v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/fabric/armfabric v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/hdinsight/armhdinsight v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/healthcareapis/armhealthcareapis/v2 v2.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/hybridcompute/armhybridcompute/v3 v3.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/iothub/armiothub v1.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/kusto/armkusto/v2 v2.4.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/loadtesting/armloadtesting v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/logic/armlogic v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/managedservices/armmanagedservices v0.7.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/maps/armmaps v1.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/msi/armmsi v1.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/netapp/armnetapp/v9 v9.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/network/armnetwork v1.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/notificationhubs/armnotificationhubs v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/oracledatabase/armoracledatabase/v3 v3.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/postgresql/armpostgresqlflexibleservers/v2 v2.1.1
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/powerbidedicated/armpowerbidedicated/v2 v2.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/privatedns/armprivatedns v1.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/purview/armpurview v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/recoveryservices/armrecoveryservices/v3 v3.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/redhatopenshift/armredhatopenshift/v2 v2.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/redisenterprise/armredisenterprise/v3 v3.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/relay/armrelay/v2 v2.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/resources/armpolicy v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/resources/armresources v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/search/armsearch v1.4.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/security/armsecurity v0.15.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/securityinsights/armsecurityinsights v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/servicefabric/armservicefabric/v2 v2.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/servicenetworking/armservicenetworking v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/solutions/armmanagedapplications/v2 v2.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storagecache/armstoragecache/v4 v4.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storagemover/armstoragemover/v2 v2.4.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storagesync/armstoragesync/v2 v2.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/streamanalytics/armstreamanalytics v1.2.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/synapse/armsynapse v0.8.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/trafficmanager/armtrafficmanager/v2 v2.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/trustedsigning/armtrustedsigning v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/webpubsub/armwebpubsub v1.3.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/workloadssapvirtualinstance/armworkloadssapvirtualinstance v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/security/keyvault/azkeys v1.5.0
	github.com/Azure/azure-sdk-for-go/sdk/security/keyvault/azsecrets v1.5.0
	github.com/Azure/azure-sdk-for-go/sdk/storage/azblob v1.8.2
	github.com/Azure/azure-sdk-for-go/sdk/storage/azdatalake v1.7.0
	github.com/Azure/azure-sdk-for-go/sdk/storage/azfile v1.7.1
	github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue v1.0.1
	github.com/Azure/go-amqp v1.7.0
	github.com/apache/arrow-go/v18 v18.7.0
	github.com/aws/aws-sdk-go-v2 v1.47.3
	github.com/aws/aws-sdk-go-v2/config v1.33.9
	github.com/aws/aws-sdk-go-v2/credentials v1.20.9
	github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue v1.21.11
	github.com/aws/aws-sdk-go-v2/feature/rds/auth v1.7.6
	github.com/aws/aws-sdk-go-v2/service/accessanalyzer v1.57.4
	github.com/aws/aws-sdk-go-v2/service/account v1.42.3
	github.com/aws/aws-sdk-go-v2/service/acm v1.50.4
	github.com/aws/aws-sdk-go-v2/service/acmpca v1.56.5
	github.com/aws/aws-sdk-go-v2/service/amp v1.54.4
	github.com/aws/aws-sdk-go-v2/service/amplify v1.49.0
	github.com/aws/aws-sdk-go-v2/service/apigateway v1.52.1
	github.com/aws/aws-sdk-go-v2/service/apigatewaymanagementapi v1.41.1
	github.com/aws/aws-sdk-go-v2/service/apigatewayv2 v1.46.1
	github.com/aws/aws-sdk-go-v2/service/appconfig v1.54.4
	github.com/aws/aws-sdk-go-v2/service/appconfigdata v1.32.4
	github.com/aws/aws-sdk-go-v2/service/appflow v1.61.5
	github.com/aws/aws-sdk-go-v2/service/appintegrations v1.51.1
	github.com/aws/aws-sdk-go-v2/service/applicationautoscaling v1.51.4
	github.com/aws/aws-sdk-go-v2/service/appstream v1.72.1
	github.com/aws/aws-sdk-go-v2/service/appsync v1.62.4
	github.com/aws/aws-sdk-go-v2/service/athena v1.66.4
	github.com/aws/aws-sdk-go-v2/service/autoscaling v1.78.4
	github.com/aws/aws-sdk-go-v2/service/backup v1.69.1
	github.com/aws/aws-sdk-go-v2/service/batch v1.78.3
	github.com/aws/aws-sdk-go-v2/service/bcmdataexports v1.25.4
	github.com/aws/aws-sdk-go-v2/service/bcmpricingcalculator v1.21.4
	github.com/aws/aws-sdk-go-v2/service/bedrock v1.73.4
	github.com/aws/aws-sdk-go-v2/service/bedrockagent v1.68.3
	github.com/aws/aws-sdk-go-v2/service/bedrockagentcorecontrol v1.72.3
	github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime v1.64.3
	github.com/aws/aws-sdk-go-v2/service/bedrockruntime v1.63.4
	github.com/aws/aws-sdk-go-v2/service/budgets v1.53.1
	github.com/aws/aws-sdk-go-v2/service/cleanrooms v1.58.0
	github.com/aws/aws-sdk-go-v2/service/cloudcontrol v1.38.4
	github.com/aws/aws-sdk-go-v2/service/cloudformation v1.82.1
	github.com/aws/aws-sdk-go-v2/service/cloudfront v1.74.3
	github.com/aws/aws-sdk-go-v2/service/cloudhsmv2 v1.43.4
	github.com/aws/aws-sdk-go-v2/service/cloudtrail v1.65.4
	github.com/aws/aws-sdk-go-v2/service/cloudwatch v1.73.3
	github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs v1.89.3
	github.com/aws/aws-sdk-go-v2/service/codeartifact v1.46.4
	github.com/aws/aws-sdk-go-v2/service/codebuild v1.78.4
	github.com/aws/aws-sdk-go-v2/service/codecommit v1.44.0
	github.com/aws/aws-sdk-go-v2/service/codedeploy v1.45.4
	github.com/aws/aws-sdk-go-v2/service/codepipeline v1.55.4
	github.com/aws/aws-sdk-go-v2/service/codestarconnections v1.44.6
	github.com/aws/aws-sdk-go-v2/service/cognitoidentity v1.42.4
	github.com/aws/aws-sdk-go-v2/service/comprehend v1.49.4
	github.com/aws/aws-sdk-go-v2/service/computeoptimizer v1.62.5
	github.com/aws/aws-sdk-go-v2/service/configservice v1.74.4
	github.com/aws/aws-sdk-go-v2/service/connect v1.204.3
	github.com/aws/aws-sdk-go-v2/service/controlcatalog v1.23.4
	github.com/aws/aws-sdk-go-v2/service/controltower v1.37.4
	github.com/aws/aws-sdk-go-v2/service/costandusagereportservice v1.43.4
	github.com/aws/aws-sdk-go-v2/service/costexplorer v1.74.1
	github.com/aws/aws-sdk-go-v2/service/costoptimizationhub v1.35.2
	github.com/aws/aws-sdk-go-v2/service/databasemigrationservice v1.75.1
	github.com/aws/aws-sdk-go-v2/service/dataexchange v1.50.5
	github.com/aws/aws-sdk-go-v2/service/datasync v1.67.4
	github.com/aws/aws-sdk-go-v2/service/datazone v1.80.0
	github.com/aws/aws-sdk-go-v2/service/dax v1.38.8
	github.com/aws/aws-sdk-go-v2/service/detective v1.47.4
	github.com/aws/aws-sdk-go-v2/service/devicefarm v1.52.2
	github.com/aws/aws-sdk-go-v2/service/directconnect v1.55.2
	github.com/aws/aws-sdk-go-v2/service/directoryservice v1.47.6
	github.com/aws/aws-sdk-go-v2/service/dlm v1.45.4
	github.com/aws/aws-sdk-go-v2/service/docdb v1.57.4
	github.com/aws/aws-sdk-go-v2/service/drs v1.51.0
	github.com/aws/aws-sdk-go-v2/service/dsql v1.22.5
	github.com/aws/aws-sdk-go-v2/service/dynamodb v1.70.3
	github.com/aws/aws-sdk-go-v2/service/dynamodbstreams v1.45.1
	github.com/aws/aws-sdk-go-v2/service/ec2 v1.338.4
	github.com/aws/aws-sdk-go-v2/service/ecr v1.66.4
	github.com/aws/aws-sdk-go-v2/service/ecs v1.100.3
	github.com/aws/aws-sdk-go-v2/service/efs v1.49.4
	github.com/aws/aws-sdk-go-v2/service/eks v1.104.1
	github.com/aws/aws-sdk-go-v2/service/elasticbeanstalk v1.43.4
	github.com/aws/aws-sdk-go-v2/service/elasticloadbalancing v1.41.4
	github.com/aws/aws-sdk-go-v2/service/elasticloadbalancingv2 v1.63.4
	github.com/aws/aws-sdk-go-v2/service/elasticsearchservice v1.51.4
	github.com/aws/aws-sdk-go-v2/service/emr v1.70.4
	github.com/aws/aws-sdk-go-v2/service/emrserverless v1.50.1
	github.com/aws/aws-sdk-go-v2/service/eventbridge v1.55.3
	github.com/aws/aws-sdk-go-v2/service/firehose v1.52.4
	github.com/aws/aws-sdk-go-v2/service/fis v1.46.4
	github.com/aws/aws-sdk-go-v2/service/fms v1.54.2
	github.com/aws/aws-sdk-go-v2/service/fsx v1.74.5
	github.com/aws/aws-sdk-go-v2/service/gamelift v1.68.1
	github.com/aws/aws-sdk-go-v2/service/globalaccelerator v1.45.3
	github.com/aws/aws-sdk-go-v2/service/glue v1.169.1
	github.com/aws/aws-sdk-go-v2/service/grafana v1.45.0
	github.com/aws/aws-sdk-go-v2/service/guardduty v1.99.1
	github.com/aws/aws-sdk-go-v2/service/iam v1.64.4
	github.com/aws/aws-sdk-go-v2/service/identitystore v1.49.1
	github.com/aws/aws-sdk-go-v2/service/imagebuilder v1.67.1
	github.com/aws/aws-sdk-go-v2/service/inspector2 v1.61.3
	github.com/aws/aws-sdk-go-v2/service/iot v1.84.4
	github.com/aws/aws-sdk-go-v2/service/iotdataplane v1.40.4
	github.com/aws/aws-sdk-go-v2/service/ivs v1.61.5
	github.com/aws/aws-sdk-go-v2/service/kafka v1.65.4
	github.com/aws/aws-sdk-go-v2/service/keyspaces v1.37.2
	github.com/aws/aws-sdk-go-v2/service/kinesis v1.56.4
	github.com/aws/aws-sdk-go-v2/service/kinesisanalyticsv2 v1.47.4
	github.com/aws/aws-sdk-go-v2/service/kinesisvideo v1.42.0
	github.com/aws/aws-sdk-go-v2/service/kms v1.61.4
	github.com/aws/aws-sdk-go-v2/service/lakeformation v1.55.4
	github.com/aws/aws-sdk-go-v2/service/lambda v1.112.1
	github.com/aws/aws-sdk-go-v2/service/lambdamicrovms v1.11.1
	github.com/aws/aws-sdk-go-v2/service/licensemanager v1.47.5
	github.com/aws/aws-sdk-go-v2/service/lightsail v1.66.4
	github.com/aws/aws-sdk-go-v2/service/location v1.59.4
	github.com/aws/aws-sdk-go-v2/service/macie2 v1.59.4
	github.com/aws/aws-sdk-go-v2/service/marketplacecatalog v1.52.4
	github.com/aws/aws-sdk-go-v2/service/marketplaceentitlementservice v1.46.4
	github.com/aws/aws-sdk-go-v2/service/marketplacemetering v1.46.1
	github.com/aws/aws-sdk-go-v2/service/mediaconvert v1.106.5
	github.com/aws/aws-sdk-go-v2/service/medialive v1.112.2
	github.com/aws/aws-sdk-go-v2/service/mediapackagev2 v1.51.3
	github.com/aws/aws-sdk-go-v2/service/memorydb v1.42.4
	github.com/aws/aws-sdk-go-v2/service/mq v1.45.4
	github.com/aws/aws-sdk-go-v2/service/mwaa v1.48.4
	github.com/aws/aws-sdk-go-v2/service/neptune v1.53.4
	github.com/aws/aws-sdk-go-v2/service/networkfirewall v1.76.1
	github.com/aws/aws-sdk-go-v2/service/networkmanager v1.50.5
	github.com/aws/aws-sdk-go-v2/service/notifications v1.17.5
	github.com/aws/aws-sdk-go-v2/service/oam v1.31.4
	github.com/aws/aws-sdk-go-v2/service/odb v1.26.2
	github.com/aws/aws-sdk-go-v2/service/opensearch v1.85.1
	github.com/aws/aws-sdk-go-v2/service/organizations v1.61.3
	github.com/aws/aws-sdk-go-v2/service/paymentcryptography v1.39.5
	github.com/aws/aws-sdk-go-v2/service/pinpointsmsvoicev2 v1.42.1
	github.com/aws/aws-sdk-go-v2/service/pipes v1.32.4
	github.com/aws/aws-sdk-go-v2/service/polly v1.65.4
	github.com/aws/aws-sdk-go-v2/service/pricing v1.49.4
	github.com/aws/aws-sdk-go-v2/service/quicksight v1.137.2
	github.com/aws/aws-sdk-go-v2/service/ram v1.45.4
	github.com/aws/aws-sdk-go-v2/service/rds v1.130.3
	github.com/aws/aws-sdk-go-v2/service/rdsdata v1.40.4
	github.com/aws/aws-sdk-go-v2/service/redshift v1.71.4
	github.com/aws/aws-sdk-go-v2/service/redshiftdata v1.49.3
	github.com/aws/aws-sdk-go-v2/service/redshiftserverless v1.44.4
	github.com/aws/aws-sdk-go-v2/service/rekognition v1.60.3
	github.com/aws/aws-sdk-go-v2/service/resiliencehub v1.44.5
	github.com/aws/aws-sdk-go-v2/service/resourceexplorer2 v1.33.4
	github.com/aws/aws-sdk-go-v2/service/resourcegroups v1.42.5
	github.com/aws/aws-sdk-go-v2/service/resourcegroupstaggingapi v1.41.4
	github.com/aws/aws-sdk-go-v2/service/route53 v1.70.4
	github.com/aws/aws-sdk-go-v2/service/route53recoverycontrolconfig v1.40.4
	github.com/aws/aws-sdk-go-v2/service/route53resolver v1.54.4
	github.com/aws/aws-sdk-go-v2/service/rum v1.38.4
	github.com/aws/aws-sdk-go-v2/service/s3 v1.114.3
	github.com/aws/aws-sdk-go-v2/service/s3control v1.79.4
	github.com/aws/aws-sdk-go-v2/service/s3tables v1.23.4
	github.com/aws/aws-sdk-go-v2/service/s3vectors v1.16.3
	github.com/aws/aws-sdk-go-v2/service/sagemaker v1.282.3
	github.com/aws/aws-sdk-go-v2/service/sagemakerruntime v1.49.4
	github.com/aws/aws-sdk-go-v2/service/scheduler v1.25.4
	github.com/aws/aws-sdk-go-v2/service/secretsmanager v1.50.4
	github.com/aws/aws-sdk-go-v2/service/securityhub v1.84.1
	github.com/aws/aws-sdk-go-v2/service/securitylake v1.34.5
	github.com/aws/aws-sdk-go-v2/service/serverlessapplicationrepository v1.39.5
	github.com/aws/aws-sdk-go-v2/service/servicecatalog v1.47.4
	github.com/aws/aws-sdk-go-v2/service/servicediscovery v1.49.4
	github.com/aws/aws-sdk-go-v2/service/servicequotas v1.43.4
	github.com/aws/aws-sdk-go-v2/service/ses v1.42.4
	github.com/aws/aws-sdk-go-v2/service/sesv2 v1.79.1
	github.com/aws/aws-sdk-go-v2/service/sfn v1.51.4
	github.com/aws/aws-sdk-go-v2/service/shield v1.43.5
	github.com/aws/aws-sdk-go-v2/service/signer v1.41.5
	github.com/aws/aws-sdk-go-v2/service/sns v1.47.5
	github.com/aws/aws-sdk-go-v2/service/sqs v1.52.4
	github.com/aws/aws-sdk-go-v2/service/ssm v1.79.3
	github.com/aws/aws-sdk-go-v2/service/sso v1.38.4
	github.com/aws/aws-sdk-go-v2/service/ssoadmin v1.49.4
	github.com/aws/aws-sdk-go-v2/service/ssooidc v1.43.4
	github.com/aws/aws-sdk-go-v2/service/storagegateway v1.52.5
	github.com/aws/aws-sdk-go-v2/service/sts v1.51.4
	github.com/aws/aws-sdk-go-v2/service/swf v1.43.4
	github.com/aws/aws-sdk-go-v2/service/textract v1.49.4
	github.com/aws/aws-sdk-go-v2/service/timestreaminfluxdb v1.29.4
	github.com/aws/aws-sdk-go-v2/service/transcribe v1.66.4
	github.com/aws/aws-sdk-go-v2/service/transfer v1.85.3
	github.com/aws/aws-sdk-go-v2/service/translate v1.43.1
	github.com/aws/aws-sdk-go-v2/service/verifiedpermissions v1.41.4
	github.com/aws/aws-sdk-go-v2/service/vpclattice v1.33.5
	github.com/aws/aws-sdk-go-v2/service/wafv2 v1.83.4
	github.com/aws/aws-sdk-go-v2/service/workspaces v1.82.0
	github.com/aws/aws-sdk-go-v2/service/workspacesweb v1.47.4
	github.com/aws/aws-sdk-go-v2/service/xray v1.46.0
	github.com/aws/smithy-go v1.28.5
	github.com/cedar-policy/cedar-go v1.8.0
	github.com/charmbracelet/x/ansi v0.11.9
	github.com/charmbracelet/x/term v0.2.2
	github.com/coder/websocket v1.8.15
	github.com/decred/dcrd/dcrec/secp256k1/v4 v4.4.1
	github.com/dop251/goja v0.0.0-20261011122007-9b0700c7e02e
	github.com/eclipse/paho.mqtt.golang v1.5.1
	github.com/go-sql-driver/mysql v1.10.1
	github.com/google/flatbuffers v25.12.19+incompatible
	github.com/googleapis/gax-go/v2 v2.26.2
	github.com/gorilla/websocket v1.5.3
	github.com/hashicorp/hcl/v2 v2.25.0
	github.com/jackc/pgx/v5 v5.11.0
	github.com/klauspost/compress v1.20.1
	github.com/microsoft/go-mssqldb v1.11.2
	github.com/mochi-mqtt/server/v2 v2.7.9
	github.com/modelcontextprotocol/go-sdk v1.8.0
	github.com/pierrec/lz4/v4 v4.1.33
	github.com/pkg/sftp v1.13.11
	github.com/rabbitmq/amqp091-go v1.15.0
	github.com/twmb/franz-go v1.22.1
	github.com/twmb/franz-go/pkg/kadm v1.19.0
	github.com/twmb/franz-go/pkg/kmsg v1.14.0
	github.com/vektah/gqlparser/v2 v2.5.62
	github.com/zclconf/go-cty v1.19.0
	go.mongodb.org/mongo-driver/v2 v2.9.2
	go.yaml.in/yaml/v3 v3.0.5
	golang.org/x/crypto v0.58.0
	golang.org/x/net v0.60.0
	golang.org/x/oauth2 v0.36.0
	golang.org/x/sys v0.49.0
	google.golang.org/api v0.288.0
	google.golang.org/genproto v0.0.0-20260715232425-e75dac1f907d
	google.golang.org/genproto/googleapis/api v0.0.0-20260715232425-e75dac1f907d
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260715232425-e75dac1f907d
	google.golang.org/grpc v1.84.0
	google.golang.org/protobuf v1.36.11
)

require (
	cel.dev/expr v0.25.2 // indirect
	cloud.google.com/go/auth v0.20.0 // indirect
	cloud.google.com/go/auth/oauth2adapt v0.2.8 // indirect
	cloud.google.com/go/compute/metadata v0.9.0 // indirect
	filippo.io/edwards25519 v1.2.0 // indirect
	github.com/Azure/azure-sdk-for-go/sdk/internal v1.13.0 // indirect
	github.com/Azure/azure-sdk-for-go/sdk/security/keyvault/internal v1.2.0 // indirect
	github.com/Azure/azure-sdk-for-go/sdk/storage/internal v0.1.0 // indirect
	github.com/AzureAD/microsoft-authentication-library-for-go v1.10.1 // indirect
	github.com/GoogleCloudPlatform/grpc-gcp-go/grpcgcp v1.6.0 // indirect
	github.com/GoogleCloudPlatform/opentelemetry-operations-go/detectors/gcp v1.35.0 // indirect
	github.com/GoogleCloudPlatform/opentelemetry-operations-go/exporter/metric v0.57.0 // indirect
	github.com/GoogleCloudPlatform/opentelemetry-operations-go/internal/resourcemapping v0.57.0 // indirect
	github.com/MicahParks/keyfunc v1.9.0 // indirect
	github.com/agext/levenshtein v1.2.1 // indirect
	github.com/agnivade/levenshtein v1.2.1 // indirect
	github.com/apache/arrow/go/v15 v15.0.2 // indirect
	github.com/apparentlymart/go-textseg/v15 v15.0.0 // indirect
	github.com/apparentlymart/go-textseg/v17 v17.0.1 // indirect
	github.com/aws/aws-sdk-go-v2/aws/protocol/eventstream v1.7.22 // indirect
	github.com/aws/aws-sdk-go-v2/feature/ec2/imds v1.20.3 // indirect
	github.com/aws/aws-sdk-go-v2/internal/configsources v1.5.6 // indirect
	github.com/aws/aws-sdk-go-v2/internal/endpoints/v2 v2.8.6 // indirect
	github.com/aws/aws-sdk-go-v2/internal/v4a v1.5.6 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/accept-encoding v1.13.21 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/checksum v1.11.7 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/endpoint-discovery v1.13.6 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/presigned-url v1.14.6 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/s3shared v1.20.6 // indirect
	github.com/aws/aws-sdk-go-v2/service/signin v1.10.4 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/charmbracelet/colorprofile v0.4.3 // indirect
	github.com/charmbracelet/ultraviolet v0.0.0-20261008173134-6b8d4baf91b4 // indirect
	github.com/charmbracelet/x/termios v0.1.1 // indirect
	github.com/charmbracelet/x/windows v0.2.2 // indirect
	github.com/clipperhouse/displaywidth v0.11.0 // indirect
	github.com/clipperhouse/uax29/v2 v2.7.0 // indirect
	github.com/cncf/xds/go v0.0.0-20260202195803-dba9d589def2 // indirect
	github.com/dlclark/regexp2/v2 v2.8.1 // indirect
	github.com/envoyproxy/go-control-plane/envoy v1.37.0 // indirect
	github.com/envoyproxy/protoc-gen-validate v1.3.3 // indirect
	github.com/felixge/httpsnoop v1.1.0 // indirect
	github.com/go-jose/go-jose/v4 v4.1.6 // indirect
	github.com/go-logr/logr v1.4.4 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/go-sourcemap/sourcemap v2.1.3+incompatible // indirect
	github.com/goccy/go-json v0.10.6 // indirect
	github.com/golang-jwt/jwt/v4 v4.5.2 // indirect
	github.com/golang-jwt/jwt/v5 v5.3.1 // indirect
	github.com/golang-sql/civil v0.0.0-20220223132316-b832511892a9 // indirect
	github.com/golang-sql/sqlexp v0.1.0 // indirect
	github.com/golang/protobuf v1.5.4 // indirect
	github.com/google/btree v1.1.3 // indirect
	github.com/google/jsonschema-go v0.4.3 // indirect
	github.com/google/pprof v0.0.0-20230207041349-798e818bf904 // indirect
	github.com/google/s2a-go v0.1.9 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/googleapis/enterprise-certificate-proxy v0.3.17 // indirect
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	github.com/klauspost/cpuid/v2 v2.4.0 // indirect
	github.com/kr/fs v0.1.0 // indirect
	github.com/kylelemons/godebug v1.1.0 // indirect
	github.com/lucasb-eyer/go-colorful v1.4.1 // indirect
	github.com/mattn/go-runewidth v0.0.30 // indirect
	github.com/mitchellh/go-wordwrap v1.0.1 // indirect
	github.com/muesli/cancelreader v0.2.2 // indirect
	github.com/pkg/browser v0.0.0-20240102092130-5ac0b6a4141c // indirect
	github.com/planetscale/vtprotobuf v0.6.1-0.20240319094008-0393e58bdf10 // indirect
	github.com/rivo/uniseg v0.4.7 // indirect
	github.com/rs/xid v1.4.0 // indirect
	github.com/segmentio/asm v1.1.3 // indirect
	github.com/segmentio/encoding v0.5.4 // indirect
	github.com/shopspring/decimal v1.4.0 // indirect
	github.com/spiffe/go-spiffe/v2 v2.8.1 // indirect
	github.com/xdg-go/pbkdf2 v1.0.0 // indirect
	github.com/xdg-go/scram v1.2.0 // indirect
	github.com/xdg-go/stringprep v1.0.4 // indirect
	github.com/xo/terminfo v1.0.0 // indirect
	github.com/yosida95/uritemplate/v3 v3.0.2 // indirect
	github.com/youmark/pkcs8 v0.0.0-20240726163527-a2c0da244d78 // indirect
	github.com/zeebo/xxh3 v1.1.0 // indirect
	go.opencensus.io v0.24.0 // indirect
	go.opentelemetry.io/auto/sdk v1.2.1 // indirect
	go.opentelemetry.io/contrib/detectors/gcp v1.45.0 // indirect
	go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc v0.68.0 // indirect
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.69.0 // indirect
	go.opentelemetry.io/otel v1.45.0 // indirect
	go.opentelemetry.io/otel/metric v1.45.0 // indirect
	go.opentelemetry.io/otel/sdk v1.45.0 // indirect
	go.opentelemetry.io/otel/sdk/metric v1.45.0 // indirect
	go.opentelemetry.io/otel/trace v1.45.0 // indirect
	golang.org/x/exp v0.0.0-20260813180055-c1d0aacb2297 // indirect
	golang.org/x/mod v0.41.0 // indirect
	golang.org/x/sync v0.24.0 // indirect
	golang.org/x/telemetry v0.0.0-20260924152758-ed294f943157 // indirect
	golang.org/x/text v0.43.0 // indirect
	golang.org/x/time v0.15.0 // indirect
	golang.org/x/tools v0.51.0 // indirect
	golang.org/x/xerrors v0.0.0-20240903120638-7835f813f4da // indirect
	google.golang.org/appengine/v2 v2.0.6 // indirect
	rsc.io/binaryregexp v0.2.0 // indirect
)
