#!/bin/bash

# Plain line before output
echo

# Get branch and environment directory
BRANCH=$(git rev-parse --symbolic --abbrev-ref "$1" 2> /dev/null)

if [ $? -gt 0 ]
then
  BRANCH=$(echo "$1" | cut -d "/" -f 3)
  IS_DELETED=1
else
  IS_DELETED=0
fi

ENV_BASEPATH='/etc/puppet/environments'
ENV="$ENV_BASEPATH/$BRANCH"
IS_NEW_ENV=0

# New branch
if [ ! -d "$ENV" ]
then
  echo "*** Cloning new environment"
  cd $ENV_BASEPATH
  git clone /var/lib/puppet/puppet.git -b "$BRANCH" "$BRANCH"
  IS_NEW_ENV=1
fi

# New branch
if [ ! -s "/etc/puppet/files/$BRANCH" ]
then
  echo "*** Symlink for fileserver"
  ln -s "$ENV/files" "/etc/puppet/files/$BRANCH"
fi

# Removed branch
if [ $IS_DELETED -eq 1 ]
then
  echo "*** Deleting environment (branch $BRANCH)"
  rm -r "$ENV"
  rm -r "/etc/puppet/files/$BRANCH"
  echo
  exit
fi

cd "$ENV"
unset GIT_DIR

echo "*** Pulling into Puppet (branch $BRANCH)"
git fetch
git reset --hard origin/"$BRANCH"

# Update librarian
if [ -f Puppetfile ]
then
  git diff "HEAD@{1}" --name-only | grep ^Puppetfile &> /dev/null
  CHANGED=$?

  echo
  if [ $CHANGED -eq 0 ] || [ $IS_NEW_ENV -eq 1 ]
  then
    echo "*** Librarian-puppet installing modules. This might take a while."
    librarian-puppet update
  else
    echo "*** Puppetfile not changed."
  fi
fi

if [[ "$BRANCH" == "production" ]]; then
  #BUG: this only sends the lastest commit in a push
  echo "*** Notification sent"
  git log -1 -p --pretty=format:"From: Puppet <git@puppet.geo>%nReply-To: <%ae>%nTo: <provoz@foodomain>%nDate: %cD%nSubject: [PUP] %s%n%n%an: %N%n%b" | mail -s "Commit to production" provoz@foobar
fi

echo
