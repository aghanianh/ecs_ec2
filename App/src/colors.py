from flask import Flask, render_template_string

app = Flask(__name__)

# Basic HTML template with dynamic background color
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Color</title>
    <style>
        body {
            background-color: {{ color }};
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            font-family: Arial, sans-serif;
            color: #fff;
        }
    </style>
</head>
<body>
    <h1>Background Color: {{ color }}</h1>
</body>
</html>
"""

colors = set()

@app.route('/color/add_<color>')
def add_color(color):
    colors.add(color) 
    return f"Color {color} added successfully!"

@app.route('/color/<color>')
def change_color(color):
    if color in colors:
        return render_template_string(HTML_TEMPLATE, color=color)
    else:
        # If the color is not in the set, show the default white background
        return render_template_string(HTML_TEMPLATE, color="white")

@app.route('/')
def home():
    return "Go to /color/add_<color> to add a new color or /color/<color> to change the background color."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
