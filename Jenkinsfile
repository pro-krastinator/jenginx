import jenkins.model.Jenkins
echo "${JOB_NAME}"

echo "n {currentBuild.previousBuild.number}"
echo "b {currentBuild.previousBuild}"
try {
if (currentBuild.previousBuild.number != null || currentBuild.previousBuild != null ) {
   def PrevBuildNum = currentBuild.previousBuild.number
} else {
   def PrevBuildNum = 0
}
}
catch (Exception e) {
    PrevBuildNum = 0
    echo "${PrevBuildNum = 0}"
}

def CurrBuild = currentBuild.number;
/*
def LastGoodBuild = 0;
def build = currentBuild.previousBuild ?: "0"
while (build != null) {
      if (build.result == "SUCCESS")
      {
         LastGoodBuild = build.id as Integer
         break
      }
      build = build.previousBuild
}
*/
def LastGoodBuild = 0

if ( Jenkins.instance.getItem("${JOB_NAME}").lastSuccessfulBuild == null || Jenkins.instance.getItem("${JOB_NAME}").lastSuccessfulBuild.number == 0 ) {
    LastGoodBuild = 0
} else {
    LastGoodBuild = Jenkins.instance.getItem("${JOB_NAME}").lastSuccessfulBuild.number;
}
echo "Last Goodd Build ID: ${LastGoodBuild}"

pipeline {
    options {
        timestamps()
    }
    agent none
    stages {
        stage('Build') {
            agent {
                dockerfile {
                    additionalBuildArgs  '-t nginx-sourced'
                }
            }
            steps {
                sh 'nginx -v'
                echo "Jenkins BUILD_NUMBER is ${BUILD_NUMBER}"
                //print PrevBuildNum
                echo "Currend build - ${CurrBuild}"
                echo "LastGoodBuild - ${LastGoodBuild}"
            }
        }

        stage('Test if the bare Nginx container is valid') {
            agent any
            steps {
                echo 'Stopping and removing nginx_sourced_1  container if any'
                sh 'docker kill nginx_sourced_1 || true'
                sh 'docker rm nginx_sourced_1 || true'
                echo "Starting container with name nginx_sourced_1 from the buit container named nginx-sourced"
                sh 'docker run -p 8081:8081 --name nginx_sourced_1 -d nginx-sourced'
                echo "Checking from Jenkins container if nginx config is valid and web-server is serving traffic"
                sh '''
                      docker exec nginx_sourced_1 curl -s -o /dev/null -I -w "%{http_code}" 127.0.0.1:8081 || exit 1;
                      docker exec nginx_sourced_1 nginx -t || exit 1
                   '''
            }

        }

        stage('Build docker image with site content') {
            agent {
                dockerfile {
                    filename "Dockerfile.prod"
                    additionalBuildArgs "-t nginx-prod-site:${BUILD_NUMBER}"
                }
            }
            steps {
                sh 'nginx -t|| exit 1'
            }
        }
        stage('Run Nginx from production docker image') {
            agent any
            steps {
                echo "Stopping and removing nginx_sourced_1 container if any (because: 1-using resources and 2-we do not need it any more"
                sh 'docker kill nginx_sourced_1 || true'
                sh 'docker rm nginx_sourced_1 || true'
                echo "Stopping and removing nginx-prod-site container if any"
                sh 'docker kill nginx-prod-site || true'
                sh 'docker rm nginx-prod-site || true'
                echo "Starting nginx-prod-site container"
                sh "docker run -p 8082:8082 --name nginx-prod-site -d nginx-prod-site:${CurrBuild}"
                echo "Checking from Jenkins container if nginx config is valid and web-server is serving traffic"
                sh '''
                      docker exec nginx-prod-site curl -s -o /dev/null -I -w "%{http_code}" 127.0.0.1:8082 || exit 1;
                      docker exec nginx-prod-site nginx -t || exit 1
                   '''
            }
        }
// TODO: Perform addidtional checks if the previous build was succesfull
// Also it would be good to think better about removeing intermediate/garbage docker images etc.
        // Dunno how to implement it is declarative, so googled scripted approach... Also todo: Get Public IP of the instance prgramatically and path to variable.

        stage('Does the site has content what we need?') {
            agent any
            steps {
                script {
                    echo "LastGoodBuild - ${LastGoodBuild}"
                    // set result of curl (true or false to a variable)
                    def siteContentCheckResult = sh(script: 'bash ./jenkins_post_check.sh', returnStdout: true) as Integer
                    echo "Variable siteContentCheckResult is ${siteContentCheckResult}"
                    if ( siteContentCheckResult == 0 ) {
                       echo 'GREAT! We do not need to rollback!'
                       currentBuild.result = 'SUCCESS'
                       RollBackCheck = 0
                       return
                       //exit 0
                    } else {
                        // We need to change value of BuildNum variable to previous
                        echo 'Oops! We really need to rollback!'
                        echo "Stopping and removing nginx_sourced_1 container if any (because: 1-using resources and 2-we do not need it any more"
                        sh 'docker kill nginx_sourced_1 || true'
                        sh 'docker rm nginx_sourced_1 || true'
                        echo "Stopping and removing nginx-prod-site container if any"
                        sh 'docker kill nginx-prod-site || true'
                        sh 'docker rm nginx-prod-site || true'
                        echo "Starting nginx-prod-site container"
                        sh "docker run -p 8082:8082 --name nginx-prod-site -d nginx-prod-site:${LastGoodBuild}"
                        echo "Checking from Jenkins container if nginx config is valid and web-server is serving traffic"
                        sh '''
                            docker exec nginx-prod-site curl -s -o /dev/null -I -w "%{http_code}" 127.0.0.1:8082 || exit 1;
                            docker exec nginx-prod-site nginx -t || exit 1
                        '''
                        RollBackCheck = 1
                        //currentBuild.result = 'FAILURE'
                    }
                    /* Despite the fact the we have rollback current changes and our site is live and passed check after roll-back,
                       this particular build should not be considered as Successful so we need to force it as FAILED */

                    echo "Since this build did not pass post check - it is FAILED - correct errors and re-run"
                    echo 'Let\'s check if our site passes our post-check AFTER rollback'
                    if ( RollBackCheck == 1 ) {
                        def RollbackCheckResult = sh(script: 'bash ./jenkins_post_check.sh', returnStdout: true) as Integer
                        if ( RollbackCheckResult != 0) {
			   echo 'Terrifying! Content still not as good as we plan. Correct things manually!'
			   sh 'exit 2'
			} else {
                           echo 'Phew! Okay, at least our site works ok!'
			   currentBuild.result = 'FAILURE'
                           sh 'exit 1' 
			}
                    } else {
                        echo 'Looks Like we are good here!'
                        return
                    }
                    //exit 1
                }
            //sh 'exit 1'
            }
        }
    }
}

