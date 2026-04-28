import { BarChart } from "@databricks/appkit-ui/react";

export function RevenueChart() {
  return (
    <BarChart
      queryKey="revenue_by_destination"
      xKey="destination"
      yKey="total_revenue"
    />
  );
}
