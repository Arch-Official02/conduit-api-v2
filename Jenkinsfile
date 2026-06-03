pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REGISTRY = '707417410763.dkr.ecr.us-east-1.amazonaws.com'
        ECR_REPOSITORY = 'conduit-api-v2'
        IMAGE_TAG = "${env.GIT_COMMIT}"
        MONGO_CONTAINER = "mongo-test-${env.BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            environment {
                NODE_ENV = 'test'
                MONGODB_URI = 'mongodb://localhost:27017/conduit-test'
            }

            steps {
                bat '''
                docker rm -f %MONGO_CONTAINER% 2>NUL || exit 0
                docker run -d --name %MONGO_CONTAINER% -p 27017:27017 mongo:4.4
                '''

                bat 'npm ci'
                bat 'npm test'
            }

            post {
                always {
                    bat 'docker rm -f %MONGO_CONTAINER% 2>NUL || exit 0'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                bat "docker build -t %ECR_REGISTRY%/%ECR_REPOSITORY%:%IMAGE_TAG% ."
                bat "docker tag %ECR_REGISTRY%/%ECR_REPOSITORY%:%IMAGE_TAG% %ECR_REGISTRY%/%ECR_REPOSITORY%:latest"
            }
        }
        stage('Debug AWS') {
            steps {
                bat '''
                aws --version
                aws sts get-caller-identity
                '''
            }
        }
        stage('Push to ECR') {
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    bat '''
                    aws ecr get-login-password --region %AWS_REGION% | docker login --username AWS --password-stdin %ECR_REGISTRY%
                    docker push %ECR_REGISTRY%/%ECR_REPOSITORY%:%IMAGE_TAG%
                    docker push %ECR_REGISTRY%/%ECR_REPOSITORY%:latest
                    '''
                }
            }
        }

        stage('Deploy to ECS Fargate') {
            steps {
                echo "Deploying image %ECR_REGISTRY%/%ECR_REPOSITORY%:%IMAGE_TAG%"
            }
        }
    }

    post {
        always {
            bat 'docker rm -f %MONGO_CONTAINER% 2>NUL || exit 0'
        }
    }
}