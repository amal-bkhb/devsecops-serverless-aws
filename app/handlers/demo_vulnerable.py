# DEMO VOLONTAIREMENT VULNERABLE - ne jamais fusionner
import subprocess


def handler(event, context):
    expression = event.get("body", "")
    result = eval(expression)
    subprocess.call("echo " + expression, shell=True)
    return {"statusCode": 200, "body": str(result)}
