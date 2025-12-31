import { useTranslation } from "react-i18next";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { ArrowLeftRight, TrendingUp } from "lucide-react";
import { Button } from "@/components/ui/button";

const Lending = () => {
  const { t } = useTranslation();

  const loans = [
    { id: "L-9082", asset: "USDT", amount: "500,000.00", rate: "8.5%", term: "30 Days", status: "Active", yield: "$3,493.15" },
    { id: "L-9085", asset: "BTC", amount: "2.50", rate: "4.2%", term: "Flexible", status: "Active", yield: "0.0086 BTC" },
  ];

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold tracking-tight">{t("dashboard.nav.lending")}</h1>
        <Button className="gap-2">
          <ArrowLeftRight size={16} />
          New Loan
        </Button>
      </div>

      <div className="grid gap-6">
        <Card className="bg-card/50 border-border/50">
          <CardHeader>
            <CardTitle className="text-lg">Active Lending Positions</CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent border-border/50">
                  <TableHead className="text-muted-foreground">ID</TableHead>
                  <TableHead className="text-muted-foreground">Asset</TableHead>
                  <TableHead className="text-muted-foreground">Amount</TableHead>
                  <TableHead className="text-muted-foreground">Rate (APY)</TableHead>
                  <TableHead className="text-muted-foreground">Status</TableHead>
                  <TableHead className="text-muted-foreground text-right">Accrued Yield</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {loans.map((loan) => (
                  <TableRow key={loan.id} className="border-border/50 hover:bg-secondary/30 transition-colors">
                    <TableCell className="font-mono text-xs">{loan.id}</TableCell>
                    <TableCell className="font-semibold">{loan.asset}</TableCell>
                    <TableCell>{loan.amount}</TableCell>
                    <TableCell className="text-primary font-medium">{loan.rate}</TableCell>
                    <TableCell>
                      <Badge variant="outline" className="bg-green-500/10 text-green-500 border-green-500/20">
                        {loan.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right font-semibold">{loan.yield}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Lending;
