pipeline {
    agent any
    parameters {
        string(name: 'PLATFORM', defaultValue: 'aarch64', description: '')
        string(name: 'ALPINE_VERSION', defaultValue: '3.12', description: '')
        string(name: 'GLIBC_VERSION', defaultValue: '2.32', description: '')
        string(name: 'GLIBC_RELEASE', defaultValue: '0', description: '')
        string(name: 'TARGET_OWNER', defaultValue: 'lauri-nomme', description: '')
        string(name: 'TARGET_REPO', defaultValue: 'alpine-glibc-xb', description: '')
    }
    environment {
        TARGET_GITHUB_TOKEN = credentials("TARGET_GITHUB_TOKEN")
        SIGN_PRIVKEY = credentials("SIGN_PRIVKEY")
    }
    stages {
        stage('Register qemu binfmt_misc') {
            steps {
                sh "docker run --rm --privileged multiarch/qemu-user-static --reset --persistent yes"
            }
        }

        stage('Build') {
            steps {
                sh  'echo PLATFORM=' + params.PLATFORM + '\n' +
                    'echo ALPINE_VERSION=' + params.ALPINE_VERSION + '\n' +
                    'echo GLIBC_VERSION=' + params.GLIBC_VERSION + '\n' +
                    'echo GLIBC_RELEASE=' + params.GLIBC_RELEASE + '\n' +
                    'echo TARGET_OWNER=' + params.TARGET_OWNER + '\n' +
                    'echo TARGET_REPO=' + params.TARGET_REPO + '\n' +
                '''
                    PRIVKEY=$(cat $SIGN_PRIVKEY)
                    docker buildx build --platform linux/$PLATFORM \
                        --build-arg ALPINE_VERSION=$ALPINE_VERSION \
                        --build-arg GLIBC_VERSION=$GLIBC_VERSION \
                        --build-arg GLIBC_RELEASE=$GLIBC_RELEASE \
                        --build-arg MAINTAINER=devops.spectx.com \
                        --build-arg "PRIVKEY=$PRIVKEY" \
                        --tag glibc:out \
                        --load \
                        .
                '''
            }
        }

        stage('Publish') {
            steps {
                sh  '''
                    ls -latr out
                    rm -rf out
                    mkdir out && chmod 777 out
                    docker run -v $(realpath out):/out --rm --entrypoint sh glibc:out -c "cp -r /packages/*.pub /packages/*/*/* /out/"
                    ~/go/bin/ghr -u $TARGET_OWNER -r $TARGET_REPO $PLATFORM-$GLIBC_VERSION-r$GLIBC_RELEASE out/
                '''
            }
        }

        stage('Cleanup') {
            steps {
                sh '''
                   docker image rm glibc:out
                   # docker buildx prune
                '''
            }
        }
    }
}
