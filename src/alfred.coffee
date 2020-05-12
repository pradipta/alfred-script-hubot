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
    require('dotenv').config()
    mysql = require 'mysql'
    url = 'mysql://'+process.env.ALFREDDBUSERNAME+':'+process.env.ALFREDDBPASSWORD+'@'+process.env.ALFREDDBHOST+':'+process.env.ALFREDDBPORT+'/'+process.env.ALFREDDBNAME
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
            res.reply("400! Instance name has not been specified")
        else
            sqlQuery = "SELECT * FROM service_instance_mapping where service_name='"+service+"' and instance_name='"+instance+"'"
        load_data = () ->
            conn.query sqlQuery, (err, rows) ->
                if err or rows.length == 0
                    robot.logger.info "Service not found"
                    res.reply "404! Service/Instance not found"
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

        service = requestArray[2]
        instance = requestArray[3]
        duration = parseInt(requestArray[4])

        if !instance
            console.log("Instance name has not been specified")
            res.reply("400! Instance name has not been specified")
            return

        if isNaN(duration)
            res.reply("400! Duration should be a NUMERIC VALUE (minutes)")
            return
    
        sqlQuery = "SELECT * FROM service_instance_mapping where service_name='"+service+"' and instance_name='"+instance+"'"
        load_data = () ->
            conn.query sqlQuery, (err, rows) ->
                if err or rows.length == 0
                    console.log(err)
                    robot.logger.info "Service not found"
                    res.reply "404! Service/Instance not found"
                else
                    isAvailable = rows[0].available
                    if isAvailable !=1
                        res.reply("410! Instance Already Occupied. Check:\n```"+JSON.stringify(rows, null, "\t")+"```")
                        return
                    date = new Date()
                    occupiedBy=res.envelope.user.name
                    sqlUpdateQuery = "UPDATE service_instance_mapping set available = 0, reserved_at ="+conn.escape(date)+", booked_by = '"+occupiedBy+"', duration = "+duration+", comments = '"+comment+"' where service_name='"+service+"' and instance_name='"+instance+"'"
                    conn.query sqlUpdateQuery, (err, rows) ->
                        if err
                            res.reply("500! Failed to reserve.")
                        else   
                            res.reply("Reserved successfully. Check and verify maybe?")
                            setTimeout(() ->
                                console.log("Inside timeout method: ",instance, service, occupiedBy)
                                console.log("This is running")
                                resetQuery = "UPDATE service_instance_mapping set available = 1, reserved_at = null, booked_by = null, duration = null, comments = null where service_name='"+service+"' and instance_name='"+instance+"'"
                                console.log(resetQuery)
                                conn.query resetQuery, (err, rows) ->
                                    if err
                                        res.send("Database couldn't be updated. Please contact my developer.")
                                    else
                                        res.reply("Your booking for instance: "+instance+" is now over.")
                                console.log("update end")    
                            , duration*60*1000);                    
        load_data()

    robot.respond /release (.*)/, (res) ->
        requestArray = res.envelope.message.text.split(" ")
        service = requestArray[2]
        instance = requestArray[3]
        if !instance
            res.reply("400! Instance name has not been specified")
            return
    
        sqlQuery = "SELECT * FROM service_instance_mapping where service_name='"+service+"' and instance_name='"+instance+"'"
        load_data = () ->
            conn.query sqlQuery, (err, rows) ->
                if err or rows.length == 0
                    robot.logger.info "Service not found"
                    res.reply "404! Service/Instance not found"
                else
                    isAvailable = rows[0].available
                    if isAvailable ==1
                        res.reply("400! Instance is not occupied to be released. \n```"+JSON.stringify(rows, null, "\t")+"```")
                        return
                    else
                        occupiedBy = rows[0].booked_by
                        if occupiedBy != res.envelope.user.name
                            res.reply("403! The instance wasn't booked by you, you cannot release it.")
                            return
                    date = new Date()
                    
                    sqlUpdateQuery = "UPDATE service_instance_mapping set available = 1, reserved_at = null, booked_by = null, duration = null, comments = null where service_name='"+service+"' and instance_name='"+instance+"'"
                    console.log(sqlUpdateQuery)
                    conn.query sqlUpdateQuery, (err, rows) ->
                        if err
                            console.log(err)
                            res.reply("500! Failed to reserve.")
                        else   
                            res.reply("Released successfully. Check and verify maybe?")
        load_data()