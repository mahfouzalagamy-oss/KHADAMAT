import { useAuth } from "@/src/auth";
import CustomerHome from "@/src/screens/CustomerHome";
import TechHome from "@/src/screens/TechHome";
import AdminHome from "@/src/screens/AdminHome";
import CompanyHome from "@/src/screens/CompanyHome";

export default function Home() {
  const { user } = useAuth();
  if (!user) return null;
  if (user.role === "technician") return <TechHome />;
  if (user.role === "admin") return <AdminHome />;
  if (user.role === "company") return <CompanyHome />;
  return <CustomerHome />;
}