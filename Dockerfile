# BASE Container with application installed.
FROM node:10-slim as baseImage

# update to latest debian stuff
RUN apt-get update && apt-get upgrade -y

WORKDIR /dist
COPY ./package.json package.json
RUN npm install --only=prod
COPY ./lib/server.js /dist/lib/server.js
COPY ./init.js /dist/init.js

# CI test steps and dev dependencies
FROM baseImage as ciTestSteps
ARG push_test_results
# Install gcloud
RUN apt-get install lsb-release -y && \
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update -y && apt-get install google-cloud-sdk -y

# RUN tests
COPY ./test/example.test.js /dist/test/example.test.js
RUN npm install --only=dev && npm test
COPY ci-pipeline-sa* ./

RUN pwd && ls -l

RUN if [ "$push_test_results" = "true" ] ; then \
    gcloud auth activate-service-account ci-pipeline@cookbook-1180.iam.gserviceaccount.com --key-file=./ci-pipeline-sa.json ; \
    gsutil cp ./out.hmtl gs://tyrconsulting-push-test/results_$(date +"%Y-%m-%d_%H-%M-%S").html ; \
    fi

# Final container which is not running as root
FROM baseImage

RUN chown -R node:node /dist
USER node

EXPOSE 3000

CMD node init.js