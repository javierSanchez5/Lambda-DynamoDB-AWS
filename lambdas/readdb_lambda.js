var AWS = require('aws-sdk');
var dynamo = new AWS.DynamoDB({ apiVersion: '2012-08-10' });

exports.handler = async (event) => {
    try {
        var requestJSON = JSON.parse(event.body);

        
        var params = {
            TableName: 'user',
            Key: {
                id: { S: requestJSON.id }
            }
        };

        var data;

        try {
            data = await dynamo.getItem(params).promise();
            console.log("User is:", data);
        } catch (err) {
            console.log("Error: ", err);
            data = err;
        }

        var response = {
            'statusCode': 200,
            'body': JSON.stringify({
                message: data
            })
        };
    } catch (err) {
        console.log(err);
        return err;
    }
    return response;
};