#!/bin/sh -e

path=/home/dpavlin/mikrotik-switch

switch=$1
test -z "$switch" && echo "Usage: $0 switch-name" && exit 1

cd $path
ssh -i $path/ssh/mikrotik admin@$switch 'export file="backup"'
scp -q -i $path/ssh/mikrotik admin@$switch:backup.rsc $path/backup/$switch.rsc

cd $path/backup
git ls-files --error-unmatch $switch.rsc || git add $switch.rsc && git commit -m "$switch initial config" && exit 0

git diff --stat $switch.rsc | grep '1 file changed, 1 insertion(+), 1 deletion(-)' > /dev/null || git commit -m "$switch `date +%Y-%m-%d`" $switch.rsc
