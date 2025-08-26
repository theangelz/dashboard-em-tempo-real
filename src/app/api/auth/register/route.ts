import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';

export async function POST(request: NextRequest) {
  try {
    const { name, email, company, role, password } = await request.json();

    // Validações
    if (!name || !email || !company || !role || !password) {
      return NextResponse.json(
        { error: 'Todos os campos são obrigatórios' },
        { status: 400 }
      );
    }

    // Validar força da senha
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$/;
    if (!passwordRegex.test(password)) {
      return NextResponse.json(
        { error: 'Senha não atende aos requisitos de segurança' },
        { status: 400 }
      );
    }

    // Validar role
    if (!['admin', 'operacao', 'juridico'].includes(role)) {
      return NextResponse.json(
        { error: 'Função inválida' },
        { status: 400 }
      );
    }

    // Hash da senha
    const hashedPassword = await bcrypt.hash(password, 10);

    // TODO: Salvar no banco de dados
    const newUser = {
      id: uuidv4(),
      name,
      email,
      company,
      role,
      password: hashedPassword,
      createdAt: new Date().toISOString()
    };

    console.log(`[AUDIT] User registered - Email: ${email}, Company: ${company}, Role: ${role}`);

    return NextResponse.json({
      message: 'Usuário criado com sucesso',
      user: {
        id: newUser.id,
        name: newUser.name,
        email: newUser.email,
        company: newUser.company,
        role: newUser.role
      }
    }, { status: 201 });

  } catch (error) {
    console.error('Registration error:', error);
    return NextResponse.json(
      { error: 'Erro interno do servidor' },
      { status: 500 }
    );
  }
}