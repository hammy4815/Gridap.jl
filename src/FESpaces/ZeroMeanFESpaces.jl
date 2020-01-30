
struct ZeroMeanFESpace <: SingleFieldFESpace
  space::FESpaceWithLastDofRemoved
  vol_i::Vector{Float64}
  vol::Float64
end

function ZeroMeanFESpace(
  space::SingleFieldFESpace,trian::Triangulation,quad::CellQuadrature)

  _space = FESpaceWithLastDofRemoved(space)
  vol_i, vol = _setup_vols(space,trian,quad)
  ZeroMeanFESpace(_space,vol_i,vol)
end

function _setup_vols(V,trian,quad)
  U = TrialFESpace(V)
  assem = SparseMatrixAssembler(V,U)
  bh = get_cell_basis(V)
  cellvec = integrate(bh,trian,quad)
  cellids = get_cell_id(trian)
  vol_i = assemble_vector(assem,[cellvec],[cellids])
  vol = sum(vol_i)
  (vol_i, vol)
end

# Genuine functions

function TrialFESpace(f::ZeroMeanFESpace)
  U = TrialFESpace(f.space)
  ZeroMeanFESpace(U,f.vol_i,f.vol)
end

function finalize_fe_function(f::ZeroMeanFESpace,uh)
  @assert is_a_fe_function(uh)
  free_values = get_free_values(uh)
  c = _compute_new_fixedval(free_values,f.vol_i,f.vol)
  fv = apply(+,free_values,Fill(c,length(free_values)))
  dv = [c,]
  FEFunction(f.space,fv,dv)
end

function _compute_new_fixedval(v,vol_i,vol)
  c = 0.0
  for (i,vi) in enumerate(v)
    c += vi*vol_i[i]
  end
  c = -c/vol
  c
end

# Delegated functions

get_dirichlet_values(f::ZeroMeanFESpace) = get_dirichlet_values(f.space)

get_cell_basis(f::ZeroMeanFESpace) = get_cell_basis(f.space)

get_cell_dof_basis(f::ZeroMeanFESpace) = get_cell_dof_basis(f.space)

num_free_dofs(f::ZeroMeanFESpace) = num_free_dofs(f.space)

zero_free_values(::Type{T},f::ZeroMeanFESpace) where T = zero_free_values(T,f.space)

apply_constraints_matrix_cols(f::ZeroMeanFESpace,cm,cids) = apply_constraints_matrix_cols(f.space,cm,cids)

apply_constraints_matrix_rows(f::ZeroMeanFESpace,cm,cids) = apply_constraints_matrix_rows(f.space,cm,cids)

apply_constraints_vector(f::ZeroMeanFESpace,cm,cids) = apply_constraints_vector(f.space,cm,cids)

get_cell_dofs(f::ZeroMeanFESpace) = get_cell_dofs(f.space)

num_dirichlet_dofs(f::ZeroMeanFESpace) = num_dirichlet_dofs(f.space)

zero_dirichlet_values(f::ZeroMeanFESpace) = zero_dirichlet_values(f.space)

num_dirichlet_tags(f::ZeroMeanFESpace) = num_dirichlet_tags(f.space)

get_dirichlet_dof_tag(f::ZeroMeanFESpace) = get_dirichlet_dof_tag(f.space)

scatter_free_and_dirichlet_values(f::ZeroMeanFESpace,fv,dv) = scatter_free_and_dirichlet_values(f.space,fv,dv)

gather_free_and_dirichlet_values(f::ZeroMeanFESpace,cv) = gather_free_and_dirichlet_values(f.space,cv)

gather_dirichlet_values(f::ZeroMeanFESpace,cv) = gather_dirichlet_values(f.space,cv)

gather_free_values(f::ZeroMeanFESpace,cv) = gather_free_values(f.space,cv)

