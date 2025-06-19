# Finance Dashboard Frontend

This is a simple Svelte dashboard using shadcn-svelte and Chart.js to visualise transaction data.

## Development

Install dependencies and start the dev server:

```bash
npm install
npm run dev
```

Open <http://localhost:5173> in your browser to view the dashboard.

The dashboard expects the API to return a JSON object with an `Items` array in
the DynamoDB attribute format. If your API URL differs, update the fetch call in
`src/App.svelte`.

