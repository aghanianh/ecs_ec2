FROM python:3.9-slim

WORKDIR /App

# Copy the src directory to the container
COPY src/ src/

# Install the required Python packages
RUN pip install flask

# Expose the port the app runs on
EXPOSE 5000

# Set the command to run the Flask app
CMD ["python", "src/colors.py"]
