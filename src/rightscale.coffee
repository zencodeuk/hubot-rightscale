# Description:
#   Rightscale huboter
#
# Commands:
#   hubot rightscale - rightscale me a_deployment / rightscale me matching a_deployment

access_token = null
refresh_token = null
tagsToRecognise = []

module.exports = (robot) ->
  robot.respond /(rightscale login) (.*)/i, (msg) ->
    refresh_token = msg.match[2]
    msg.send 'Thanks - rightscale away!'
  
  robot.respond /(rightscale me deployment) (.*)/i, (msg) ->
    rightscaleListDeployment(robot, msg, msg.match[2])

  robot.respond /(rightscale me) ([a-zA-Z0-9\\-]*)$/i, (msg) ->
    rightscaleListDeployments(robot, msg, "(#{msg.match[2]})")

  robot.respond /(rightscale recognise) ([a-zA-Z0-9\\-]*)$/i, (msg) ->
    tagsToRecognise.push msg.match[2]
    msg.send "Thanks - #{msg.match[2]} me away!"

  robot.respond /(rightscale summary) ([a-zA-Z0-9\\-]*)$/i, (msg) ->
    summarise(robot, msg, msg.match[2])

  robot.respond /([a-zA-Z0-9\\-]*) me(.*)?/i, (msg) ->
    if tagIsRecognised(msg.match[1])
      optionalLocality = if msg.match[2] then msg.match[2].trim() else '.*'
      summarise(robot, msg, msg.match[1], optionalLocality)

summarise = (robot, msg, pattern, locality='.*') ->
  regex = "(#{pattern})(.*)(#{locality})"
  rightscaleDeployments robot, msg, regex, (deployments) ->
    for deployment in deployments
      deploymentId = extractId(deployment)
      location = 'deployments/'+deploymentId+'/server_arrays'
      rightscaleRequest robot, msg, location, {asset: 'server_arrays', deployment: deploymentId}, (err, response) ->
        for serverArray in response
          do (serverArray) ->
            rightscaleRequest robot, msg, 'server_arrays/'+extractId(serverArray)+'/current_instances', {}, (err, response) ->
              serverCount = 0
              nonOperationalCount = 0
              for server in response
                serverCount +=  1
                if server.state != "operational"
                  msg.send "WARNING #{server.name} is #{server.state}"
                  nonOperationalCount += 1
              msg.send "#{serverArray.name} #{serverCount} server(s), #{nonOperationalCount} are non operational"

rightscaleListDeployments = (robot, msg, pattern='.*') ->
  rightscaleDeployments robot, msg, pattern, (deployments) ->
      output = []
      for deployment in deployments
        output.push deployment.name
      
      msg.send output.join("\n") + "\nFound #{deployments.length} deployments"
    

rightscaleDeployments = (robot, msg, pattern='', callback) ->
  params = {}
  regex = new RegExp("(.*)#{pattern}(.*)", 'i')
  rightscaleRequest robot, msg, 'deployments', params, (err, response) ->
    matchingDeployments = []

    for deployment in response
      if deployment.name.match regex
        matchingDeployments.push deployment

    callback(matchingDeployments)


rightscaleListDeployment = (robot, msg, deploymentName) ->  
  findDeployment robot, deploymentName, msg, (deployment) ->
      deploymentId = extractId(deployment)
      location = 'deployments/'+deploymentId+'/server_arrays'
      rightscaleRequest robot, msg, location, {asset: 'server_arrays', deployment: deploymentId}, (err, response) ->
        for serverArray in response
          do (serverArray) ->
            rightscaleRequest robot, msg, 'server_arrays/'+extractId(serverArray)+'/current_instances', {}, (err, response) ->
              output = []
              output.push "#{serverArray.name} https://us-3.rightscale.com/deployments/#{extractId(serverArray)}"
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
   rightscaleRequest robot, msg, 'deployments', params, (err, response) ->
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
      func(err, JSON.parse(body))

delay = (ms, func) -> setTimeout func, ms

tagIsRecognised = (item_to_find) ->
  for item in tagsToRecognise
    return true if item == item_to_find
  false