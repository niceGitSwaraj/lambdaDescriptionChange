#!/bin/bash
#make it so we can append, remove and update
#to run the script, simply pass in the "command" and the "description" as arguments to the script.
#there are 3 commands - add, update and clear. Add will append to current description, update will replace and clear will remove current description.
#eg: ./lambdaDescriptionCHange.sh add "This is the new Description"
#    ./lambdaDescriptionCHange.sh update "This is the updated description"
#    ./lambdaDescriptionCHange.sh clear         
#    ./lambdaDescriptionCHange.sh remove "StringToBeRemoved"         
# For all the above functions, the lambda function name can be passed in. If function name is not provided, it will apply to all functions
COMMAND=$1
REPLACEMENT_STRING=$2
FUNCTION_NAME=$3
echo ${COMMAND}
echo ${REPLACEMENT_STRING}
OPT_IN="${1:-true}"
OPT_IN_STRING=" aws:states:opt-in"
AWS_TARGET_PROFILE="niceResearcher"
MAX_PAGE_ITEMS="50" #max 50
AWS_CLI_COMMAND="aws lambda list-functions --region us-east-2 --max-items ${MAX_PAGE_ITEMS}"
AWS_COMMAND_OUTPUT=""

aws lambda list-functions --region us-east-2

function cli_call() {
  if [ -z "$NEXT_TOKEN" ]; then
    iteration_output="$($AWS_CLI_COMMAND)"
  else
    iteration_output="$($AWS_CLI_COMMAND --starting-token $NEXT_TOKEN)"
  fi

  NEXT_TOKEN="$(echo $iteration_output | jq -r '.NextToken')"
  processed_iteration="$(echo ${iteration_output} | jq '.Functions[] | {FunctionName, Description}' | jq -c -r '@base64' )"
  if [ -z "$CLI_OUTPUT" ]; then
    CLI_OUTPUT="${processed_iteration}"
  else CLI_OUTPUT+="
${processed_iteration}"
  fi
}

while [ "$NEXT_TOKEN" != "null" ]; do
  cli_call $NEXT_TOKEN
done


size=${#FUNCTION_NAME} 

echo "Number of records: $(echo "${CLI_OUTPUT}" | wc -l)"

	for jsonObj in $(echo ${CLI_OUTPUT}); do
	  LAMBDA_JSON="$(echo "$jsonObj" | base64 --decode)"
	  LAMBDA_NAME="$(echo "${LAMBDA_JSON}" | jq -r '.FunctionName')"
	  LAMBDA_DESC="$(echo "${LAMBDA_JSON}" | jq -r '.Description')"
	  # check if the description already includes the opt-in string
	  #if [[ "$LAMBDA_DESC" == *"$OPT_IN_STRING"* ]]; then
	  #  if [[ "$OPT_IN" == "true" ]]; then
	  #    LAMBDA_DESC="$LAMBDA_DESC"
	  #  else
	  #    LAMBDA_DESC="${LAMBDA_DESC/$OPT_IN_STRING/}"
	  #  fi
	  #else
	  #  if [[ "$OPT_IN" == "true" ]]; then
	  #    LAMBDA_DESC="$LAMBDA_DESC $OPT_IN_STRING"
	  #  fi
	  #fi
	  
	  if [[ ${COMMAND} == "add" ]]; then
		LAMBDA_DESC="$LAMBDA_DESC $REPLACEMENT_STRING"
		echo "Adding - ${LAMBDA_DESC}"
	  elif [[ ${COMMAND} == "update" ]]; then
		  LAMBDA_DESC="$REPLACEMENT_STRING"
		  echo "Updating to- ${LAMBDA_DESC}"   	
	  elif [[ ${COMMAND} == "clear" ]]; then
		  LAMBDA_DESC="-"
		  echo "Clearing - ${LAMBDA_DESC}"
	  elif [[ ${COMMAND} == "remove" ]]; then
	      DATA=${LAMBDA_DESC/$REPLACEMENT_STRING/}
	      LAMBDA_DESC="${DATA}"
		  echo "Removing - ${LAMBDA_DESC}"
	  fi
	  	  
	  if [[ "$FUNCTION_NAME" ]]; 
	  then		  
	      if [ "$LAMBDA_NAME" == "$FUNCTION_NAME" ]
		  then
			  echo "changing $LAMBDA_NAME function"
			  aws lambda update-function-configuration --region us-east-2 --function-name "$LAMBDA_NAME" --description "${LAMBDA_DESC}"	
			  break
		  fi
	  else
	      echo "changing all function"
		  echo "--------- $LAMBDA_DESC"
		  #if [[ "$LAMBDA_NAME" == "poc-helloworld-lambda" ]]; then
		  aws lambda update-function-configuration --region us-east-2 --function-name "$LAMBDA_NAME" --description "${LAMBDA_DESC}"
		  echo "$LAMBDA_NAME description updated: $LAMBDA_DESC"
	  fi
	  #break
	  #fi
	done
#fi