# Description:
#   Alfred Hubot
#
# Dependencies:
#   None
#
# Configuration:
#   None
# 
# Commands:
#   hubot check <service-name>
#   hubot check <service-name> <instance-name>
#   hubot reserve <service-name> <instance-name> <duration>
#   hubot reserve <service-name> <instance-name> <duration> <comment>
#   hubot release <service-name> <instance-name>
#
# Author:
#   pradipta.sarma

module.exports = (robot) ->
    tag = 'check-servers'
    mysql = require 'mysql'
    url = 'mysql://root:ueducation@localhost:3306/alfred'
    serviceTable = 'service'
    instanceTable = 'instance'

    serviceInstanceMappingTable = 'service_instance_mapping'

    conn = mysql.createConnection(url)
    
    robot.respond /check (.*)/, (res) ->
        requestArray = res.envelope.message.text.split(" ")
        service = requestArray[2]
        instance = requestArray[3]
        sqlQuery = "SELECT * FROM service_instance_mapping where service_name='"+service+"'"
        if !instance
            console.log("Instance name has not been specified")
        else
            sqlQuery = "SELECT * FROM service_instance_mapping where service_name='"+service+"' and instance_name='"+instance+"'"
        console.log("Query: ",sqlQuery)
        # console.log('Service Name: '+service)
        # console.log('Instance Name: '+instance)
        load_data = () ->
            conn.query sqlQuery, (err, rows) ->
                if err or rows.length == 0
                    console.log(err)
                    robot.logger.info "Service not found"
                    res.reply "Service/Instance not found"
                else
                    res.reply("```"+JSON.stringify(rows,null, "\t")+"```")

        load_data()

    robot.respond /reserve (.*)/, (res) ->
        requestArray = res.envelope.message.text.split(" ")
        comment = ""
        i=5
        while i < requestArray.length
            comment=comment+requestArray[i] + " "
            i++
    
        console.log(comment)
        service = requestArray[2]
        instance = requestArray[3]
        duration = parseInt(requestArray[4])

        if !instance
            console.log("Instance name has not been specified")
            res.reply("```Must specify instance name as well```")
            return

        if isNaN(duration)
            res.reply("Duration should be an NUMERIC VALUE (minutes)")
            return
    
        sqlQuery = "SELECT * FROM service_instance_mapping where service_name='"+service+"' and instance_name='"+instance+"'"
        load_data = () ->
            conn.query sqlQuery, (err, rows) ->
                if err or rows.length == 0
                    console.log(err)
                    robot.logger.info "Service not found"
                    res.reply "Service/Instance not found"
                else
                    isAvailable = rows[0].available
                    if isAvailable !=1
                        res.reply("```Instance Already Occupied. \n"+JSON.stringify(rows, null, "\t")+"```")
                        return
                    date = new Date()
                    occupiedBy=res.envelope.user.name
                    sqlUpdateQuery = "UPDATE service_instance_mapping set available = 0, reserved_at ="+conn.escape(date)+", booked_by = '"+occupiedBy+"', duration = 120, comments = '"+comment+"' where service_name='"+service+"' and instance_name='"+instance+"'"
                    console.log(sqlUpdateQuery)
                    conn.query sqlUpdateQuery, (err, rows) ->
                        if err
                            console.log(err)
                            res.reply("Failed to reserve.")
                        else   
                            res.reply("```Reserved successfully. Check and verify maybe?```")
        load_data()

    robot.respond /release (.*)/, (res) ->
        requestArray = res.envelope.message.text.split(" ")
        service = requestArray[2]
        instance = requestArray[3]
        if !instance
            console.log("Instance name has not been specified")
            res.reply("```Must specify instance name as well```")
            return
    
        sqlQuery = "SELECT * FROM service_instance_mapping where service_name='"+service+"' and instance_name='"+instance+"'"
        load_data = () ->
            conn.query sqlQuery, (err, rows) ->
                if err or rows.length == 0
                    console.log(err)
                    robot.logger.info "Service not found"
                    res.reply "Service/Instance not found"
                else
                    isAvailable = rows[0].available
                    if isAvailable ==1
                        res.reply("```Instance is not occupied to be released. \n"+JSON.stringify(rows, null, "\t")+"```")
                        return
                    else
                        occupiedBy = rows[0].booked_by
                        if occupiedBy != res.envelope.user.name
                            res.reply("The instance wasn't booked by you, you cannot release it")
                            return
                    date = new Date()
                    sqlUpdateQuery = "UPDATE service_instance_mapping set available = 1, reserved_at = null, booked_by = null, duration = null, comments = null where service_name='"+service+"' and instance_name='"+instance+"'"
                    console.log(sqlUpdateQuery)
                    conn.query sqlUpdateQuery, (err, rows) ->
                        if err
                            console.log(err)
                            res.reply("Failed to reserve.")
                        else   
                            res.reply("```Released successfully. Check and verify maybe?```")
        load_data()