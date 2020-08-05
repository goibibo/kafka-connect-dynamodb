FROM 017357459259.dkr.ecr.ap-south-1.amazonaws.com/sidecar:v11
ARG env

RUN if [ "${env}" == "pp" ] ; then echo "AWS_ROLE_ARN=arn:aws:iam::017357459259:role/hermes-pp-eks-role">/var/spool/cron/root ; fi && \
 if [ "${env}" != "pp" ] ; then echo "AWS_ROLE_ARN=arn:aws:iam::017357459259:role/hermes-eks-role">/var/spool/cron/root ; fi && \
 echo "AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token">>/var/spool/cron/root && \
 echo "2 0-23 * * * /bin/bash /custom_script/copy_applogs_s3.sh >> /dev/stdout 2>&1">>/var/spool/cron/root && \
 echo "*/5 * * * * /bin/bash /custom_script/sumo_auto_restart.sh >> /dev/stdout 2>&1">>/var/spool/cron/root

COPY dockerconfig/${env}/sumocollector.json /etc/sumo-sources.json
COPY dockerconfig/${env}/copy_applogs_s3.sh /custom_script/copy_applogs_s3.sh
COPY dockerconfig/${env}/shutdown_copy_applogs_s3.sh /custom_script/shutdown_copy_applogs_s3.sh

CMD ["/usr/bin/supervisord", "-n"]
