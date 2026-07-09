type LoadingStateProps = {
  message?: string;
};

export function LoadingState({ message = 'Carregando...' }: LoadingStateProps) {
  return (
    <div className="state-screen">
      <div className="state-card">
        <div className="loader" />
        <p>{message}</p>
      </div>
    </div>
  );
}
