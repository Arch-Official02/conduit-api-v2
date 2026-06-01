pipeline {
    agent any

    environment {
        AWS_REGION          = 'us-east-1'
        ECR_REGISTRY        = '707417410763.dkr.ecr.us-east-1.amazonaws.com'
        ECR_REPOSITORY      = 'conduit-api-v2'
        IMAGE_TAG           = "${env.GIT_COMMIT}"
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Test') {
    steps {
        echo 'Starting MongoDB for tests...'
        bat 'docker run -d --name mongo-test -p 27017:27017 mongo:4.4'
        
        echo 'Installing dependencies...'
        bat 'npm ci'
        
        echo 'Running Jest tests...'
        bat 'npm test'
    }
    environment {
        NODE_ENV    = 'test'
        MONGODB_URI = 'mongodb://localhost:27017/conduit-test'
    }
    post {
        always {
            echo 'Stopping MongoDB test container...'
            bat 'docker stop mongo-test || exit 0'
            bat 'docker rm mongo-test || exit 0'
        }
    }
}


        stage('Build Docker Image') {
            steps {
                echo "Building Docker image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
                bat "docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG} ."
                bat "docker tag ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest"
            }
        }

        stage('Push to ECR') {
            steps {
                echo 'Logging into ECR and pushing image...'
                bat """
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                """
            }
        }

        stage('Deploy to ECS Fargate') {
            steps {
                echo 'Deploying to ECS Fargate...'
                echo 'ECS infrastructure will be configured after Terraform setup'
                echo "Image deployed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed — check logs above'
        }
    }
}