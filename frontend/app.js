const API_BASE = "/api";

const form = document.getElementById("expense-form");
const amount = document.getElementById("amount");
const category = document.getElementById("category");
const description = document.getElementById("description");
const expenseDate = document.getElementById("expense-date");
const message = document.getElementById("message");
const list = document.getElementById("expense-list");
const empty = document.getElementById("empty");
const total = document.getElementById("total");
const monthTotal = document.getElementById("month-total");
const expenseCount = document.getElementById("expense-count");
const health = document.getElementById("health");

expenseDate.value = new Date().toISOString().slice(0, 10);

function money(value) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
  }).format(value);
}

async function checkHealth() {
  try {
    const response = await fetch(`${API_BASE}/health`);
    if (!response.ok) throw new Error();
    health.textContent = "API online";
  } catch {
    health.textContent = "API offline";
  }
}

async function loadExpenses() {
  try {
    const response = await fetch(`${API_BASE}/expenses`);
    if (!response.ok) throw new Error("Failed to load expenses");

    const expenses = await response.json();

    list.innerHTML = "";
    empty.style.display = expenses.length ? "none" : "block";

    let allTotal = 0;
    let currentMonthTotal = 0;
    const currentMonth = new Date().toISOString().slice(0, 7);

    expenses.forEach((expense) => {
      allTotal += Number(expense.amount);

      if (expense.expense_date.slice(0, 7) === currentMonth) {
        currentMonthTotal += Number(expense.amount);
      }

      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${expense.expense_date}</td>
        <td>${escapeHtml(expense.category)}</td>
        <td>${escapeHtml(expense.description || "-")}</td>
        <td>${money(expense.amount)}</td>
        <td>
          <button class="delete" data-id="${expense.id}">Delete</button>
        </td>
      `;

      list.appendChild(row);
    });

    total.textContent = money(allTotal);
    monthTotal.textContent = money(currentMonthTotal);
    expenseCount.textContent = `${expenses.length} expense${expenses.length === 1 ? "" : "s"}`;
  } catch (error) {
    message.textContent = error.message;
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  message.textContent = "Saving...";

  try {
    const response = await fetch(`${API_BASE}/expenses`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amount.value,
        category: category.value,
        description: description.value,
        expense_date: expenseDate.value,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || "Failed to save expense");
    }

    form.reset();
    expenseDate.value = new Date().toISOString().slice(0, 10);
    message.textContent = "Expense added successfully.";
    await loadExpenses();
  } catch (error) {
    message.textContent = error.message;
  }
});

list.addEventListener("click", async (event) => {
  if (!event.target.classList.contains("delete")) return;

  const id = event.target.dataset.id;

  try {
    const response = await fetch(`${API_BASE}/expenses/${id}`, {
      method: "DELETE",
    });

    const data = await response.json();

    if (!response.ok) throw new Error(data.error || "Delete failed");

    await loadExpenses();
  } catch (error) {
    message.textContent = error.message;
  }
});

document.getElementById("refresh").addEventListener("click", loadExpenses);

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

checkHealth();
loadExpenses();

// --- AWS Infrastructure: ALB DNS & Serving Frontend EC2 Instance ---
async function loadInfrastructure() {
  const servingIpEl = document.getElementById("serving-ip");
  const lastCheckedEl = document.getElementById("infra-last-checked");

  try {
    const response = await fetch(`/instance-info.json?_=${Date.now()}`, {
      cache: "no-store",
    });
    if (!response.ok) {
      throw new Error(`HTTP status: ${response.status}`);
    }
    const data = await response.json();

    if (servingIpEl) {
      servingIpEl.textContent = data.public_ip || "Unavailable";
      servingIpEl.className = "ip-pill";
    }

    if (lastCheckedEl) {
      lastCheckedEl.textContent = new Date().toLocaleTimeString();
    }
  } catch (error) {
    console.warn("Infrastructure fetch error:", error);
    if (servingIpEl) {
      servingIpEl.textContent = "Unable to fetch";
      servingIpEl.className = "ip-pill warning";
    }
    if (lastCheckedEl) {
      lastCheckedEl.textContent = `${new Date().toLocaleTimeString()} (failed)`;
    }
  }
}

const infraRefreshBtn = document.getElementById("infra-refresh");
if (infraRefreshBtn) {
  infraRefreshBtn.addEventListener("click", () => {
    loadInfrastructure();
  });
}

loadInfrastructure();
setInterval(loadInfrastructure, 30000);

// --- Generate Report via AWS Lambda & S3 Pre-signed URL ---
const reportButton = document.getElementById("report-button");
const reportStatus = document.getElementById("report-status");

if (reportButton) {
  reportButton.addEventListener("click", async () => {
    reportButton.disabled = true;
    reportButton.textContent = "Generating Report...";

    if (reportStatus) {
      reportStatus.style.display = "block";
      reportStatus.className = "report-box loading";
      reportStatus.innerHTML =
        "Connecting to AWS Lambda & querying PostgreSQL RDS...";
    }

    const endpoint = `${API_BASE}/reports`;

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(
          errorData.message || `Server responded with ${response.status}`
        );
      }

      const data = await response.json();

      if (reportStatus) {
        reportStatus.className = "report-box success";
        reportStatus.innerHTML = `
          <strong>Expense Report Generated!</strong>
          <div class="report-meta">
            <span>Expenses: <strong>${escapeHtml(data.expense_count)}</strong></span> |
            <span>Total: <strong>${money(data.total_amount)}</strong></span><br>
            <span>Generated: ${new Date(data.generated_at).toLocaleString()}</span>
          </div>
          <a href="${escapeHtml(data.report_url)}" class="report-download-btn" target="_blank" rel="noopener noreferrer">
            Download / View Report
          </a>
        `;
      }
    } catch (err) {
      console.error("Report generation error:", err);
      if (reportStatus) {
        reportStatus.className = "report-box error";
        reportStatus.innerHTML = `<strong>Failed to generate report:</strong> ${escapeHtml(
          err.message || "Unknown error"
        )}`;
      }
    } finally {
      reportButton.disabled = false;
      reportButton.textContent = "Generate Expense Report (AWS Lambda)";
    }
  });
}

