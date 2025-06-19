<script>
  import { onMount } from 'svelte';
  import Chart from 'chart.js/auto';

  let canvas;
  let categories = {};

  onMount(async () => {
    const res = await fetch('https://p6kcw3gkqc.execute-api.eu-west-1.amazonaws.com/dev/transactions');
    const data = await res.json();

    data.forEach(item => {
      const cat = item.category.S;
      const debit = parseFloat(item.debit_amount.S || '0');
      if (!categories[cat]) categories[cat] = 0;
      categories[cat] += debit;
    });

    const labels = Object.keys(categories);
    const values = Object.values(categories);

    new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [{
          label: 'Expenses',
          data: values,
          backgroundColor: 'rgba(54, 162, 235, 0.5)'
        }]
      },
      options: {
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Expense' }
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
