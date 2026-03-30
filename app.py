from flask import Flask, jsonify, request

app = Flask(__name__)

# Simple in-memory store
items = [
    {"id": 1, "name": "item_one", "value": 100},
    {"id": 2, "name": "item_two", "value": 200},
]


@app.route("/", methods=["GET"])
def index():
    return jsonify({"message": "DevSecOps Flask API", "status": "running"})


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy"})


@app.route("/items", methods=["GET"])
def get_items():
    return jsonify({"items": items})


@app.route("/items/<int:item_id>", methods=["GET"])
def get_item(item_id):
    item = next((i for i in items if i["id"] == item_id), None)
    if item is None:
        return jsonify({"error": "Item not found"}), 404
    return jsonify(item)


@app.route("/items", methods=["POST"])
def create_item():
    data = request.get_json()
    if not data or "name" not in data:
        return jsonify({"error": "Missing 'name' field"}), 400
    new_item = {
        "id": max(i["id"] for i in items) + 1,
        "name": data["name"],
        "value": data.get("value", 0),
    }
    items.append(new_item)
    return jsonify(new_item), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
