# Description:
#   Rightscale huboter
#
# Commands:
#   hubot rightscale - rightscale me a_deployment / rightscale me matching a_deployment

access_token = null
refresh_token = null

module.exports = (robot) ->
  robot.respond /(rightscale login) (.*)/i, (msg) ->
    refresh_token = msg.match[2]
    msg.send 'Thanks - rightscale away!'

  robot.respond /(rightscale me deployment) (.*)/i, (msg) ->
    rightscaleListDeployment(robot, msg, msg.match[2])

  robot.respond /(rightscale me) ([a-zA-Z0-9]*)$/i, (msg) ->
    rightscaleDeployments(robot, msg, msg.match[2])

rightscaleDeployments = (robot, msg, pattern='') ->
  params = {}
  rightscaleRequest robot, msg, 'deployments', params, (response) ->
    count = 0
    matchingDeployments = []

    for deployment in response
      if (deployment.name.indexOf(pattern) >= 0)
        matchingDeployments.push deployment.name
        count += 1

    matchingDeployments.push 'Found '+count+' deployments matching '+pattern
    msg.send matchingDeployments.join("\n")

rightscaleListDeployment = (robot, msg, deploymentName) ->
  
  findDeployment robot, deploymentName, msg, (deployment) ->
      deploymentId = extractId(deployment)
      location = 'deployments/'+deploymentId+'/server_arrays'
      rightscaleRequest robot, msg, location, {asset: 'server_arrays', deployment: deploymentId}, (response) ->
        for serverArray in response
          rightscaleRequest robot, msg, 'server_arrays/'+extractId(serverArray)+'/current_instances', {}, (response) ->
            output = []
            output.push serverArray.name
            for server in response
              output.push '\t  '+server.name+' ('+server.private_ip_addresses+') '+server.state 
            msg.send output.join('\n')

rightscaleLogin = (robot, msg, callback) ->
  params = {grant_type: "refresh_token", refresh_token: refresh_token}
  
  robot.http('https://us-3.rightscale.com/api/oauth2')
    .header('X_API_VERSION', '1.5')
    .query(params)
    .post() (err, res, body) ->
      response = JSON.parse(body)
      access_token = response.access_token
      callback(robot)

extractId = (resource) ->
  for link in resource.links
    if (link.rel == 'self')
      return /[^/]*$/.exec(link.href)[0]

  return null

findDeployment = (robot, deploymentName, msg, callback) ->
   params = {}
   rightscaleRequest robot, msg, 'deployments', params, (response) ->
      for deployment in response
        if (deployment.name == deploymentName)
          callback(deployment)

rightscaleRequest = (robot, msg, location, params, func) ->
  if !refresh_token
    msg.send 'Please rightscale login $access_token first'
    return

  if !access_token
    rightscaleLogin robot, msg, (robot) ->
      rightscaleGet(robot, msg, location, params, func)
      delay 1000*60*10, -> access_token = null
  else
    rightscaleGet(robot, msg, location, params, func)

rightscaleGet = (robot, msg, location, params, func) ->
  robot.http('https://us-3.rightscale.com/api/'+location)
    .header('X_API_VERSION', '1.5')
    .header('Authorization', 'Bearer '+access_token)
    .query(params)
    .get() (err, res, body) ->
      response = JSON.parse(body)
      func(response)

delay = (ms, func) -> setTimeout func, ms