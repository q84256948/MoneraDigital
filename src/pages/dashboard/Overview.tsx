import { useTranslation } from "react-i18next";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  AreaChart,
  Area
} from 'recharts';
import { Wallet, ArrowUpRight, ArrowDownRight, TrendingUp, Shield } from "lucide-react";
import { cn } from "@/lib/utils";

const data = [
  { name: '01', balance: 4000000 },
  { name: '02', balance: 4200000 },
  { name: '03', balance: 3900000 },
  { name: '04', balance: 4500000 },
  { name: '05', balance: 4800000 },
  { name: '06', balance: 5200000 },
  { name: '07', balance: 5100000 },
];

const Overview = () => {
  const { t } = useTranslation();

  const stats = [
    { 
      label: t("dashboard.overview.totalBalance"), 
      value: "$5,120,432.84", 
      change: "+12.5%", 
      isPositive: true,
      icon: Wallet
    },
    { 
      label: t("dashboard.overview.activeLending"), 
      value: "$2,450,000.00", 
      change: "4 Active Loans", 
      isPositive: true,
      icon: TrendingUp
    },
    { 
      label: "Estimated Monthly Yield", 
      value: "$42,670.12", 
      change: "+3.2%", 
      isPositive: true,
      icon: ArrowUpRight
    },
    { 
      label: "Platform Security", 
      value: "Level 4", 
      change: "Verified", 
      isPositive: true,
      icon: Shield
    },
  ];

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold tracking-tight">{t("dashboard.nav.overview")}</h1>
      </div>

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => (
          <Card key={stat.label} className="bg-card/50 border-border/50">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                {stat.label}
              </CardTitle>
              <stat.icon size={16} className="text-primary" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stat.value}</div>
              <p className={cn(
                "text-xs mt-1",
                stat.isPositive ? "text-green-500" : "text-red-500"
              )}>
                {stat.change}
              </p>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-7">
        {/* Performance Chart */}
        <Card className="col-span-4 bg-card/50 border-border/50">
          <CardHeader>
            <CardTitle className="text-base font-semibold">Portfolio Performance</CardTitle>
          </CardHeader>
          <CardContent className="pl-2">
            <div className="h-[300px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data}>
                  <defs>
                    <linearGradient id="colorBalance" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="hsl(var(--primary))" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="hsl(var(--primary))" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                  <XAxis 
                    dataKey="name" 
                    stroke="hsl(var(--muted-foreground))" 
                    fontSize={12}
                    tickLine={false}
                    axisLine={false}
                  />
                  <YAxis 
                    stroke="hsl(var(--muted-foreground))" 
                    fontSize={12}
                    tickLine={false}
                    axisLine={false}
                    tickFormatter={(value) => `$${value / 1000000}M`}
                  />
                  <Tooltip 
                    contentStyle={{ 
                      backgroundColor: 'hsl(var(--card))', 
                      borderColor: 'hsl(var(--border))',
                      color: 'hsl(var(--foreground))'
                    }}
                    itemStyle={{ color: 'hsl(var(--primary))' }}
                  />
                  <Area 
                    type="monotone" 
                    dataKey="balance" 
                    stroke="hsl(var(--primary))" 
                    strokeWidth={2}
                    fillOpacity={1} 
                    fill="url(#colorBalance)" 
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Market Indicators / Recent Activity */}
        <Card className="col-span-3 bg-card/50 border-border/50">
          <CardHeader>
            <CardTitle className="text-base font-semibold">Market Indicators</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-6">
              {[
                { name: "BTC / USD", price: "$64,231.50", change: "+2.4%", trend: "up" },
                { name: "ETH / USD", price: "$3,412.12", change: "-0.8%", trend: "down" },
                { name: "USDT Lending Rate", price: "8.24% APY", change: "+0.15%", trend: "up" },
                { name: "Global Mkt Cap", price: "$2.41T", change: "+1.2%", trend: "up" },
              ].map((item) => (
                <div key={item.name} className="flex items-center justify-between">
                  <div className="space-y-1">
                    <p className="text-sm font-medium leading-none">{item.name}</p>
                    <p className="text-sm text-muted-foreground">{item.price}</p>
                  </div>
                  <div className={cn(
                    "flex items-center gap-1 text-sm font-medium",
                    item.trend === "up" ? "text-green-500" : "text-red-500"
                  )}>
                    {item.trend === "up" ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
                    {item.change}
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Overview;
