import { useTranslation } from "react-i18next";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Shield, Lock, Smartphone, Key, Globe } from "lucide-react";

const Security = () => {
  const { t } = useTranslation();

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold tracking-tight">{t("dashboard.security.title")}</h1>
      </div>

      <div className="grid gap-6">
        {/* Password Change */}
        <Card className="bg-card/50 border-border/50">
          <CardHeader>
            <div className="flex items-center gap-2">
              <Lock className="text-primary" size={20} />
              <CardTitle className="text-lg">{t("dashboard.security.password")}</CardTitle>
            </div>
            <CardDescription>Update your password to keep your account secure.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4 max-w-md">
            <div className="space-y-2">
              <Label htmlFor="current-password">Current Password</Label>
              <Input id="current-password" type="password" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="new-password">New Password</Label>
              <Input id="new-password" type="password" />
            </div>
            <Button>{t("dashboard.security.password")}</Button>
          </CardContent>
        </Card>

        <div className="grid gap-6 md:grid-cols-2">
          {/* 2FA */}
          <Card className="bg-card/50 border-border/50">
            <CardHeader>
              <div className="flex items-center gap-2">
                <Smartphone className="text-primary" size={20} />
                <CardTitle className="text-lg">{t("dashboard.security.twoFactor")}</CardTitle>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground mb-4">
                Add an extra layer of security to your account by enabling two-factor authentication.
              </p>
              <div className="flex items-center justify-between p-3 rounded-lg bg-secondary/50 border border-border/50">
                <div className="text-sm font-medium">Status: <span className="text-red-500">Disabled</span></div>
                <Button variant="outline" size="sm">Enable</Button>
              </div>
            </CardContent>
          </Card>

          {/* Whitelist */}
          <Card className="bg-card/50 border-border/50">
            <CardHeader>
              <div className="flex items-center gap-2">
                <Globe className="text-primary" size={20} />
                <CardTitle className="text-lg">{t("dashboard.security.whitelist")}</CardTitle>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground mb-4">
                Restrict withdrawals to only pre-approved wallet addresses.
              </p>
              <Button variant="outline" size="sm">Manage Addresses</Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default Security;
