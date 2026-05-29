const API_BASE_URL = "https://sharedgrocery-fn-vdljxb.azurewebsites.net/api";

const state = {
  loading: false,
};

const elements = {
  refreshBtn: document.getElementById("refreshBtn"),
  addForm: document.getElementById("addForm"),
  itemInput: document.getElementById("itemInput"),
  addBtn: document.getElementById("addBtn"),
  deleteAllBtn: document.getElementById("deleteAllBtn"),
  itemsList: document.getElementById("itemsList"),
  alertContainer: document.getElementById("alertContainer"),
};

function setLoading(isLoading) {
  state.loading = isLoading;
  elements.refreshBtn.disabled = isLoading;
  elements.addBtn.disabled = isLoading;
  elements.deleteAllBtn.disabled = isLoading;
}

function showAlert(message, type = "info") {
  const alert = document.createElement("div");
  alert.className = `alert alert-${type} py-2 mb-2`;
  alert.role = "alert";
  alert.textContent = message;

  elements.alertContainer.innerHTML = "";
  elements.alertContainer.appendChild(alert);
}

function clearAlert() {
  elements.alertContainer.innerHTML = "";
}

function renderItems(items) {
  elements.itemsList.innerHTML = "";

  if (!items.length) {
    const empty = document.createElement("li");
    empty.className = "list-group-item text-body-secondary";
    empty.textContent = "No items yet.";
    elements.itemsList.appendChild(empty);
    return;
  }

  const sortedItems = [...items].sort((a, b) => a.item_name.localeCompare(b.item_name));

  sortedItems.forEach((item) => {
    const li = document.createElement("li");
    li.className = "list-group-item d-flex justify-content-between align-items-center gap-2";

    const name = document.createElement("span");
    name.className = "text-break";
    name.textContent = item.item_name;

    const deleteBtn = document.createElement("button");
    deleteBtn.className = "btn btn-outline-danger btn-sm flex-shrink-0";
    deleteBtn.textContent = "Delete";
    deleteBtn.addEventListener("click", async () => {
      if (!item.id) {
        showAlert("Cannot delete this item because it is missing an id.", "warning");
        return;
      }
      await deleteItem(item.id);
    });

    li.appendChild(name);
    li.appendChild(deleteBtn);
    elements.itemsList.appendChild(li);
  });
}

async function request(path, options = {}) {
  const headers = {};
  if (options.body) {
    headers["Content-Type"] = "application/json";
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers,
    ...options,
  });

  if (response.status === 204) {
    return null;
  }

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    const errorMessage = data.error || `Request failed with status ${response.status}.`;
    throw new Error(errorMessage);
  }

  return data;
}

async function loadItems() {
  setLoading(true);
  clearAlert();

  try {
    const items = await request("/items", { method: "GET" });
    renderItems(Array.isArray(items) ? items : []);
  } catch (error) {
    showAlert(error.message, "warning");
    renderItems([]);
  } finally {
    setLoading(false);
  }
}

async function addItem(itemName) {
  setLoading(true);
  clearAlert();

  try {
    await request("/items", {
      method: "POST",
      body: JSON.stringify({ item_name: itemName }),
    });

    elements.itemInput.value = "";
    await loadItems();
  } catch (error) {
    showAlert(error.message, "danger");
  } finally {
    setLoading(false);
  }
}

async function deleteItem(itemId) {
  setLoading(true);
  clearAlert();

  try {
    await request(`/items/${encodeURIComponent(itemId)}`, { method: "DELETE" });
    await loadItems();
  } catch (error) {
    showAlert(error.message, "danger");
  } finally {
    setLoading(false);
  }
}

async function deleteAllItems() {
  const confirmed = window.confirm("Delete all items from the list?");
  if (!confirmed) {
    return;
  }

  setLoading(true);
  clearAlert();

  try {
    const result = await request("/items", { method: "DELETE" });
    const deletedCount = result && typeof result.deleted_count === "number" ? result.deleted_count : 0;
    showAlert(`Deleted ${deletedCount} item(s).`, "success");
    await loadItems();
  } catch (error) {
    showAlert(error.message, "danger");
  } finally {
    setLoading(false);
  }
}

function bindEvents() {
  elements.refreshBtn.addEventListener("click", loadItems);
  elements.deleteAllBtn.addEventListener("click", deleteAllItems);

  elements.addForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const itemName = elements.itemInput.value.trim();

    if (!itemName) {
      showAlert("Item name is required.", "warning");
      return;
    }

    await addItem(itemName);
  });
}

function init() {
  bindEvents();
  loadItems();
}

init();