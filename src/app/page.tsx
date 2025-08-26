import { MadeWithLasy } from "@/components/made-with-lasy";

export default function Home() {
  return (
    <div className="grid grid-rows-[1fr_20px] items-center justify-items-center min-h-screen p-8 pb-20 sm:p-20 font-[family-name:var(--font-geist-sans)]">
      <main className="flex flex-col gap-8 row-start-1 items-center sm:items-start">
        <h1 className="text-4xl font-bold mb-4">Bem Vindo ao Seu Novo App</h1>
        <p className="text-xl text-gray-600">
          Hora de transformar ideias em realidade!
        </p>
      </main>
      <MadeWithLasy />
    </div>
  );
}
