var AWS = require('aws-sdk');
var dynamo = new AWS.DynamoDB({ apiVersion: '2012-08-10' });

exports.handler = async (event) => {
    try {
        var requestJSON = JSON.parse(event.body);
        var params = {
            TableName: 'user',
            Item: {
                id: { S: requestJSON.id },
                username: { S: requestJSON.name }
            }
        };
        var data;
        var msg;
        try {
            data = await dynamo.putItem(params).promise();
            console.log("User saved", data);
            msg = 'User Saved';
        } catch (err) {
            console.log("Error: ", err);
            msg = err;
        }
        var response = {
            'statusCode': 200,
            'body': JSON.stringify({
                message: msg
            })
        };
    } catch (err) {
        console.log(err);
        return err;
    }

    return response;
};