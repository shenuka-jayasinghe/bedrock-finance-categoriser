<script>
  import { onMount } from 'svelte';
  import Chart from 'chart.js/auto';

  let canvas;
  let categories = {};

  function parseAmount(str) {
    if (!str) return 0;
    // Remove common currency symbols and commas before parsing
    const cleaned = str.replace(/[^0-9+\-\.]/g, '');
    const num = parseFloat(cleaned);
    return isNaN(num) ? 0 : num;
  }

  onMount(async () => {
    const res = await fetch(
      'https://p6kcw3gkqc.execute-api.eu-west-1.amazonaws.com/dev/transactions'
    );
    const data = await res.json();

    const items = Array.isArray(data) ? data : data.Items || [];

    items.forEach((item) => {
      const cat = item.category.S;
      const debit = parseAmount(item.debit_amount?.S);
      const credit = parseAmount(item.credit_amount?.S);

      if (!categories[cat]) categories[cat] = { debit: 0, credit: 0 };
      categories[cat].debit += debit;
      categories[cat].credit += credit;
    });

    const labels = Object.keys(categories);
    const debitValues = labels.map((l) => categories[l].debit);
    const creditValues = labels.map((l) => categories[l].credit);

    new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [
          {
            label: 'Debits',
            data: debitValues,
            backgroundColor: 'rgba(54, 162, 235, 0.5)'
          },
          {
            label: 'Credits',
            data: creditValues,
            backgroundColor: 'rgba(255, 99, 132, 0.5)'
          }
        ]
      },
      options: {
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Amount' }
          }
        }
      }
    });
  });
</script>

<main class="p-4">
  <div class="card p-4">
    <canvas bind:this={canvas}></canvas>
  </div>
</main>

<style>
  .card {
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    border-radius: 8px;
  }
</style>
