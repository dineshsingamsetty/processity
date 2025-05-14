param storageAccountName string = 'salesforcestoragexyz' // must be globally unique
param functionAppName string = 'salesforce-function-app'
param dataFactoryName string = 'salesforceReplicationADF'
param adlsContainerName string = 'data'  // delta tables container
param appServicePlanName string = 'salesforce-plan'
param clientId string = '097aab76-695c-4dd8-ac54-59208ed54a85'

@secure()
param clientSecret string

param tenantId string = '996bd0dd-99d7-4a7d-bab1-27ed7b99c2a4'
param adfPipelineName string = 'CopyAccountFromSalesforce'
param location string = 'East US'

// Storage Account for Azure Function and Data Lake
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// Azure Data Lake Container (part of the same Storage Account)
resource dataLakeContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccount.name}/default/${adlsContainerName}'
  properties: {
    publicAccess: 'None'
  }
}

// App Service Plan for Azure Function
resource hostingPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'functionapp'
  properties: {}
}

// Azure Function App
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      pythonVersion: '3.10'
      linuxFxVersion: 'python|3.10'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
        name: 'WEBSITE_RUN_FROM_PACKAGE'
        value: '1'
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: clientId
        }
        {
          name: 'AZURE_CLIENT_SECRET'
          value: clientSecret
        }
        {
          name: 'AZURE_TENANT_ID'
          value: tenantId
        }
        {
          name: 'AZURE_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'AZURE_RESOURCE_GROUP'
          value: resourceGroup().name
        }
        {
          name: 'DATA_FACTORY_NAME'
          value: dataFactoryName
        }
        {
          name: 'ADF_PIPELINE_NAME'
          value: adfPipelineName
        }
      ]
    }
    httpsOnly: true
  }
}

// Azure Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}
