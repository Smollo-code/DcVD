#!/bin/bash

source .env

URL_REGEX='/^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)$/'

function getMessages() {
  echo 'startet'
  curl -s -H -w "%{http_code}" -o response.json "Authorization: Bot $BOT_TOKEN" \
    "https://discord.com/api/v10/channels/$CHANNEL_ID/messages"
  echo "HTTP-Status: $response"
  }

function matchesUrl() {
  if [[ "$1" =~ ^https?:// ]]; then # better regex needed
    return 0
  fi
  return 1
}

function createVideoFromLink() {
  local url="$1"
  local output_template="video.%(ext)s"

  yt-dlp -f 'mp4' --max-filesize 10M --print after_move:filepath -o "$output_template" "$url"
}

function sendVideoToChannel() {
  curl --http1.1 -X POST "https://discord.com/api/v10/channels/$CHANNEL_ID/messages" \
    -H "Authorization: Bot $BOT_TOKEN" \
    -H "Content-Type: multipart/form-data" \
    -F "files[0]=@$1;type=video/mp4"
}

function deleteMessage() {
  curl -X DELETE "https://discord.com/api/v10/channels/$CHANNEL_ID/messages/$1" \
    -H "Authorization: Bot $BOT_TOKEN"
}

getMessages | jq -c '.[]' | while read -r item; do
  id=$(jq -r '.id' <<< "$item")
  content=$(jq -r '.content' <<< "$item")
  if ! matchesUrl $content; then
      continue
  fi

  video=$(createVideoFromLink "$content")
  sendVideoToChannel "$video"
  deleteMessage $id
  rm video.mp4
done
