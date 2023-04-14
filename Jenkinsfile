pipeline {
    agent any
    tools {
        terraform 'terraform'
    }


    environment {
        PATH = sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        APP_REPO_NAME = "phonebookcoy"
        ACR_REGISTRY = "phonebookcoy.azurecr.io"
        APP_NAME = "todo"
        MY_RESOURCE_GROUP = "phonebook-rg"
    }

    stages {
        stage('Create Infrastructure for the App') {
            steps {
                sh 'az login --identity'
                echo 'Creating Infrastructure for the App on Azure Cloud'
                sh 'terraform init'
                sh 'terraform apply --auto-approve'
            }
        }

        stage('Create ACR Repo') {
            steps {
                echo 'Creating ACR Repo for App'
                sh 'az acr create --resource-group ${MY_RESOURCE_GROUP} --name ${APP_REPO_NAME} --sku Basic'
            }
        }

        stage('Build App Docker Image') {
            steps {
                echo 'Building App Image'
                script {
                    env.NODE_IP = sh(script: 'terraform output -raw nodejs_public_ip', returnStdout:true).trim()
                    env.DB_HOST = sh(script: 'terraform output -raw postgresql_private_ip', returnStdout:true).trim()
                }
                sh 'echo ${DB_HOST}'
                sh 'echo ${NODE_IP}'
                sh 'envsubst < node-env-template > ./nodejs/server/.env'
                sh 'cat ./nodejs/server/.env'
                sh 'envsubst < react-env-template > ./react/client/.env'
                sh 'cat ./react/client/.env'
                sh 'docker build --force-rm -t "$ACR_REGISTRY/$APP_REPO_NAME:postgr" -f ./postgresql/dockerfile-postgresql .'
                sh 'docker build --force-rm -t "$ACR_REGISTRY/$APP_REPO_NAME:nodejs" -f ./nodejs/dockerfile-nodejs .'
                sh 'docker build --force-rm -t "$ACR_REGISTRY/$APP_REPO_NAME:react" -f ./react/dockerfile-react .'
                sh 'docker image ls'
            }
        }

        stage('Push Image to ECR Repo') {
            steps {
                echo 'Pushing App Image to ECR Repo'
                sh 'az acr login --name ${ACR_REGISTRY} --expose-token | jq -r ".accessToken" | docker login --username 00000000-0000-0000-0000-000000000000 --password-stdin "$ACR_REGISTRY"'
                sh 'docker push "$ACR_REGISTRY/$APP_REPO_NAME:postgr"'
                sh 'docker push "$ACR_REGISTRY/$APP_REPO_NAME:nodejs"'
                sh 'docker push "$ACR_REGISTRY/$APP_REPO_NAME:react"'
            }
        }

        stage('Deploy the App') {
            steps {
                echo 'Deploy the App'
                sh 'ls -l'
                sh 'ansible --version'
                sh 'ansible-inventory --graph'
                ansiblePlaybook credentialsId: 'ssh', disableHostKeyChecking: true, installation: 'ansible', inventory: 'inventory_azure_vm.yml', playbook: 'playbook.yml'
             }
        }

        stage('Destroy the infrastructure'){
            steps{
                timeout(time:5, unit:'DAYS') {
                    input message:'Approve terminate'
                }
                sh """
                docker image prune -af
                terraform destroy --auto-approve
                az acr delete --name ${APP_REPO_NAME} --yes
                """
            }
        }
    }

    post {
        always {
            echo 'Deleting all local images'
            sh 'docker image prune -af'
        }

        failure {
            echo 'Delete the Image Repository on ECR due to the Failure'
            sh """
                az acr delete --name ${APP_REPO_NAME} --yes
            """
            echo 'Deleting Terraform Stack due to the Failure'
                sh 'terraform destroy --auto-approve'
        }
    }
}