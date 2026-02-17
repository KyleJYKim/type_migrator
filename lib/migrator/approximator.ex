defmodule Migrator.Approximator do

  #key_types = {:atom, :pid, :port, :reference, :float, :integer, :bitstring, :binary, :tuple, :open_map, :fun, :list}

  def promote(field_org) do
    promoter = fn left_org ->
      case left_org do
        # {:union, {left_u, right_u}} -> {:union, {left_u |> promoter_fun.(), right_u |> promoter_fun.()}}

        {:open_map, _} -> {:open_map, [left_org]}
        {:struct, _} -> {:open_map, [left_org]}
        {:tuple, _} -> {:tuple, [left_org]}
        :empty_list -> {:list, [left_org]}
        {:non_empty_list, _} -> {:list, [left_org]}
        {:fun, _} -> {:fun, [left_org]}
        {:gradual, :fun} -> {:fun, [left_org]}
        {:interval, _} -> {:integer, [left_org]}
        {:atom, singleton} -> {:atom, [singleton]}
        {:atom_req, _} -> {:atom, [left_org]}

        _ -> {left_org, [left_org]}
      end
    end
    field_org |> Enum.map(fn {left_f, right_f} -> {left_f |> promoter.(), right_f} end)
  end

  def map(fields) do
    merging = fn {list1, field_m}, merging_fun ->
        merging_fun = &merging_fun.(&1, merging_fun)
        case list1 do
          [] -> {field_m, []}
          [field_l1 | rest_l1] ->
            {field_m_new, rest_l1_new} = {rest_l1, field_m} |> merging_fun.()
            if field_m_new == nil do
              {nil, [field_l1 | rest_l1_new]}
            else
              {{left_l1, left_l1_org}, right_l1} = field_l1
              {{left_m, left_m_org}, right_m} = field_m_new
              # If K^s' in L_1
              key_type_found_in_list? = left_l1 == left_m
              left_m |> IO.inspect(label: "Key-type Found in List1?")
              left_l1 |> IO.inspect(label: "Key-type Found in List2?")
              # If atom^s' in L_1
              atom_type_found_in_list? = left_l1 == :atom
              # If K union s is a subtype of K union s'
              {left_m_org_new, merging_org_type_subtype?} = if key_type_found_in_list? do
                {left_m_org, left_l1_org} |> IO.inspect(label: "BEFORE UNIFYING TYPES") |> unify_types() |> IO.inspect(label: "AFTER UNIFYING TYPES")
              else
                {left_m_org, false} |> IO.inspect(label: "AFTER NOT-UNIFYING TYPES")
              end

              # key_type_found_in_list? |> IO.inspect(label: "KEY_TYPE_FOUND_IN_LIST?")
              # atom_type_found_in_list? |> IO.inspect(label: "ATOM_TYPE_FOUND_IN_LIST?")
              # merging_org_type_subtype? |> IO.inspect(label: "MERGING_ORG_TYPE_SUBTYPE?")

              cond do
                key_type_found_in_list? and !atom_type_found_in_list? and merging_org_type_subtype? ->
                  {nil, [field_l1 | rest_l1_new]}
                key_type_found_in_list? and !atom_type_found_in_list? and !merging_org_type_subtype? ->
                  {{{left_m, left_m_org_new}, (right_l1 ++ right_m) |> Enum.uniq()}, rest_l1_new}
                key_type_found_in_list? and atom_type_found_in_list? and merging_org_type_subtype? ->
                  {nil, [field_l1 | rest_l1_new]}
                key_type_found_in_list? and atom_type_found_in_list? and !merging_org_type_subtype? ->
                  # [{:atom_req, :k}, :atom]
                  atom_req_in_list? = left_m_org_new |> Enum.reduce(false, fn t, acc -> if is_tuple(t) and t |> elem(0) == :atom_req, do: true, else: acc end)
                  atom_set_in_list? = left_m_org_new |> Enum.reduce(false, fn t, acc -> if is_atom(t) and t == :atom, do: true, else: acc end)
                  cond do
                    atom_req_in_list? -> {field_m_new, [field_l1 | rest_l1_new]}
                    atom_set_in_list? -> {field_m_new, [field_l1 | rest_l1_new]}
                    true -> {{{left_m, left_m_org_new}, (right_l1 ++ right_m) |> Enum.uniq()}, rest_l1_new}
                  end
                !key_type_found_in_list? ->
                  {field_m_new, [field_l1 | rest_l1_new]}
              end
            end
        end
      end

    checking_if_set = fn fields -> fields |> Enum.map(fn {left_f, right_f} ->
          right_f_new = right_f |> Enum.reduce({nil}, fn type, acc ->
              case acc do
                {nil} -> type
                {:union, _} -> {:union, {type, acc}}
                acc_t -> {:union, {type, acc_t}}
              end
            end)
          right_f_new = case left_f do
            {:atom, [atom_req: _]} -> right_f_new
            _ -> {:if_set, right_f_new}
          end
          {left_f, right_f_new}
        end)
      end

    merging_total = fn fields ->
        fields |> Enum.reduce([], fn field, list1 ->
            {field_new, list_l1_new} = {list1, field} |> merging.(merging)
            if field_new == nil do
              list_l1_new
            else
              [field_new | list_l1_new]
            end
          end) |> checking_if_set.()
      end

    removing_extra_information = fn fields ->
        fields |> Enum.map(fn {{key_type, org_type}, right_f} ->
          case org_type do
            [atom_req: singleton] -> {{:atom, singleton}, right_f}
            _ -> {key_type, right_f}
          end
        end)
      end

    fields |> merging_total.() |> removing_extra_information.()
  end

  defp unify_types({type1, type2}) do
    [types1, types2] = [type1, type2] |> Enum.map(fn t -> if is_list(t), do: t, else: t |> flatten_from_union_type() end)

    types1 |> Enum.reduce({types2, true}, fn t1, {acc_types, acc_subtype?} ->
      {new_types, new_subtype?} = acc_types |> Enum.reduce({acc_types, false}, fn t2, {acc_new_types, acc_new_subtype?} ->
        case {t1, t2} |> IO.inspect(label: "{T1, T2} in Unify TYPES") do
          # Deleting from acc is not necessary but let's fix it later..

          _ when t1 == t2 -> {acc_types, true}
          {_, :term} -> {acc_types, true}
          {:none, _} -> {acc_types, true}

          {{:atom_req, _}, :atom} -> {acc_new_types, true}
          {:atom, {:atom_req, _}} -> {acc_new_types ++ [:atom], false or acc_new_subtype?} # Keep the singleton here
          {{:atom_req, _}, {:atom_req, _}} -> {(acc_new_types |> List.delete(t2)) ++ [t1, t2], false or acc_new_subtype?}

          {{:atom, _}, :atom} -> {acc_new_types, true}
          {:atom, {:atom, _}} -> {(acc_new_types |> List.delete(t2)) ++ [:atom], false or acc_new_subtype?}
          {{:atom, _}, {:atom, _}} -> {(acc_new_types |> List.delete(t2)) ++ [t1, t2], false or acc_new_subtype?}

          {{:interval, _}, :integer} -> {acc_new_types, true}
          {:integer, {:interval, _}} -> {(acc_new_types |> List.delete(t2)) ++ [:integer], false or acc_new_subtype?}
          {{:interval, {n1_1, n1_2}}, {:interval, {n2_1, n2_2}}} -> {unified_type, subtype?} = {:interval, {{n1_1, n1_2}, {n2_1, n2_2}}} |> merge_types()
            {(acc_new_types |> List.delete(t2)) ++ unified_type, subtype? or acc_new_subtype?}

          {:empty_list, {:non_empty_list, _}} -> {(acc_new_types |> List.delete(t2)) ++ [:empty_list, t2], false or acc_new_subtype?}
          {{:non_empty_list, _}, :empty_list} -> {(acc_new_types |> List.delete(t2)) ++ [t1, :empty_list], false or acc_new_subtype?}
          {{:non_empty_list, {t1_c, t1_t}}, {:non_empty_list, {t2_c, t2_t}}} -> {unified_type, subtype?} = {:non_empty_list, {{t1_c, t1_t}, {t2_c, t2_t}}} |> merge_types()
            {(acc_new_types |> List.delete(t2)) ++ unified_type, subtype? or acc_new_subtype?}

          {{:tuple, els1}, {:tuple, els2}} -> {unified_type, subtype?} = {:tuple, {els1, els2}} |> merge_types()
            {(acc_new_types |> List.delete(t2)) ++ unified_type, subtype? or acc_new_subtype?}

          {{:fun, _}, :fun} -> {acc_new_types, true}
          {:fun, {:fun, _}} -> {(acc_new_types |> List.delete(t2)) ++ [:fun], false or acc_new_subtype?}
          {{:fun, {ts1_in, t1_out}}, {:fun, {ts2_in, t2_out}}} -> {unified_type, subtype?} = {:fun, {{ts1_in, t1_out}, {ts2_in, t2_out}}} |> merge_types()
            {(acc_new_types |> List.delete(t2)) ++ unified_type, subtype? or acc_new_subtype?}
          #{:gradual, :fun} -> {:fun, [left_org]}

          {{:open_map, fields1}, {:open_map, fields2}} -> {unified_type, subtype?} = {:open_map, {fields1, fields2}} |> merge_types()
            {(acc_new_types |> List.delete(t2)) ++ unified_type, subtype? or acc_new_subtype?}

          {{:struct, _}, {:struct, {:__struct_top__, _}}} -> {acc_new_types, true}
          {{:struct, {:__struct_top__, _}}, {:struct, _}} -> {(acc_new_types |> List.delete(t2)) ++ [t1], false or acc_new_subtype?}
          {{:struct, fields1}, {:struct, fields2}} -> {unified_type, subtype?} = {:struct, {fields1, fields2}} |> merge_types()
            {(acc_new_types |> List.delete(t2)) ++ unified_type, subtype? or acc_new_subtype?}

          _ -> {(acc_new_types |> List.delete(t2)) ++ [t1, t2], false or acc_new_subtype?}
        end
      end)
      {new_types, new_subtype? and acc_subtype?} |> IO.inspect(label: "UNIFICATION RESULT in THE MIDDLE")
    end)
  end

  defp merge_types({:interval, {{n1_1, n1_2}, {n2_1, n2_2}}}) do # (n1_1..n1_2) U (n2_1..n2_2)
    min = [n1_1, n1_2, n2_1, n2_2] |> Enum.reduce(:infty, fn n, min -> if n == :infty, do: min, else: (if min == :infty, do: n, else: (if n < min, do: n, else: min)) end)
    max = [n1_1, n1_2, n2_1, n2_2] |> Enum.reduce(:infty, fn n, max -> if n == :infty, do: max, else: (if max == :infty, do: n, else: (if n > max, do: n, else: max)) end)
    {inf_neg, inf_pos} = {min - 1, max + 1}
    [n1_1_new, n2_1_new] = [n1_1, n2_1] |> Enum.map(fn n -> if n == :infty, do: inf_neg, else: n end)
    [n1_2_new, n2_2_new] = [n1_2, n2_2] |> Enum.map(fn n -> if n == :infty, do: inf_pos, else: n end)
    cond do
      n1_1_new..n1_2_new |> Range.disjoint?(n2_1_new..n2_2_new) -> {[{:interval, {n1_1, n1_2}}, {:interval, {n2_1, n2_2}}], false}

      n1_1_new == n2_1_new and n1_2_new == n2_2_new -> {[], true}
      n1_1_new < n2_1_new and n1_2_new == n2_2_new -> {[{:interval, {n1_1, n2_2}}], false}
      n1_1_new > n2_1_new and n1_2_new == n2_2_new -> {[], true}
      n1_1_new == n2_1_new and n1_2_new < n2_2_new -> {[], true}
      n1_1_new == n2_1_new and n1_2_new > n2_2_new -> {[{:interval, {n1_1, n1_2}}], false}

      n1_1_new < n2_1_new and n1_2_new < n2_2_new -> {[{:interval, {n1_1, n2_2}}], false}
      n1_1_new < n2_1_new and n1_2_new > n2_2_new -> {[{:interval, {n1_1, n1_2}}], false}
      n1_1_new > n2_1_new and n1_2_new < n2_2_new -> {[], true}
      n1_1_new > n2_1_new and n1_2_new > n2_2_new -> {[{:interval, {n2_1, n1_2}}], false}
    end
  end

  defp merge_types({:non_empty_list, {{t1_c, t1_t}, {t2_c, t2_t}}}) do
    {unified_type_c, subtype_c?} = {t1_c, t2_c} |> unify_types()
    {unified_type_t, subtype_t?} = {t1_t, t2_t} |> unify_types()

    if subtype_c? and subtype_t? do
      {[], true}
    else
      {[{:non_empty_list, {unified_type_c |> Enum.uniq() |> unflatten_to_union_type(), unified_type_t |> Enum.uniq() |> unflatten_to_union_type()}}], false}
    end
  end

  defp merge_types({:tuple, {els1, els2}}) do
    els1 |> Enum.zip(els2) |> Enum.reduce({els2, true}, fn {t1, t2}, {acc_els, acc_subtype?} ->
        {unified_type, subtype?} = {t1, t2} |> unify_types()
        cond do
        subtype? and length(els1) <= length(els2) ->
          {acc_els, true and acc_subtype?}
        subtype? and length(els1) > length(els2) ->
          {acc_els, false}
        !subtype? ->
          new_acc_els = acc_els |> Enum.map(fn t -> if t == t2, do: unified_type |> Enum.uniq() |> unflatten_to_union_type(), else: t end)
          {new_acc_els, false}
        end
      end)
  end

  defp merge_types({:fun, {{ts1_in, t1_out}, {ts2_in, t2_out}}}) do
    case {ts1_in, ts2_in} do
      {_, :all_arity} ->
        {_, subtype_out?} = {t1_out, t2_out} |> unify_types()
        if subtype_out? do
          {{:fun, {ts2_in, t2_out}}, true}
        else
          {[{:fun, {ts1_in, t1_out}}, {:fun, {ts2_in, t2_out}}], false}
        end
      {:all_arity, _} ->
        {[{:fun, {ts1_in, t1_out}}, {:fun, {ts2_in, t2_out}}], false}
      _ ->
        if length(ts1_in) == length(ts1_in) do
          {_, subtype_out?} = {t1_out, t2_out} |> unify_types()
          # input type of function: contra-variant
          subtype_in? = ts2_in |> Enum.zip(ts1_in) |> Enum.reduce(true, fn {t2, t1}, acc_subtype? ->
            {_, subtype_in?} = {t2, t1} |> unify_types()
            subtype_in? and acc_subtype?
          end)
          if subtype_in? and subtype_out? do
            {{:fun, {ts2_in, t2_out}}, true}
          else
            {[{:fun, {ts1_in, t1_out}}, {:fun, {ts2_in, t2_out}}], false}
          end
        else
          {[{:fun, {ts1_in, t1_out}}, {:fun, {ts2_in, t2_out}}], false}
        end
    end
  end

  defp merge_types({:open_map, {fields1, fields2}}) when is_list(fields1) and is_list(fields2) do
    subtype? = fields1 |> Enum.reduce(true, fn f1, acc_subtype? ->
      new_subtype? = fields2 |> Enum.reduce(false, fn f2, acc_new_subtype? ->
        {l1, r1} = f1
        {l2, r2} = f2
        [r1, r2] = [r1, r2] |> Enum.map(fn r ->
            case r do
              {:if_set, t} -> t
              _ -> r
            end
          end)
        {_, l_subtype?} = {l1, l2} |> unify_types()
        {_, r_subtype?} = {r1, r2} |> unify_types()
        (l_subtype? and r_subtype?) or acc_new_subtype?
      end)
      new_subtype? and acc_subtype?
    end)
    if subtype? do
      {[{:open_map, fields2}], true}
    else
      {[{:open_map, fields1}, {:open_map, fields2}], false}
    end
  end

  defp merge_types({:struct, {{label1, fields1}, {label2, fields2}}}) when is_list(fields1) and is_list(fields2) do
    subtype? = fields1 |> Enum.reduce(true, fn f1, acc_subtype? ->
      new_subtype? = fields2 |> Enum.reduce(false, fn f2, acc_new_subtype? ->
        {l1, r1} = f1
        {l2, r2} = f2
        [r1, r2] = [r1, r2] |> Enum.map(fn r ->
            case r do
              {:if_set, t} -> t
              _ -> r
            end
          end)
        {_, l_subtype?} = {l1, l2} |> unify_types()
        {_, r_subtype?} = {r1, r2} |> unify_types()
        (l_subtype? and r_subtype?) or acc_new_subtype?
      end)
      new_subtype? and acc_subtype?
    end)
    if subtype? do
      {[{:struct, {label2, fields2}}], true}
    else
      {[{:struct, {label1, fields1}}, {:struct, {label2, fields2}}], false}
    end
  end

  defp flatten_from_union_type(type) when is_tuple(type) or is_atom(type) do
    case type do
      {:union, {type_l, type_r}} -> ([type_l |> flatten_from_union_type()] ++ [type_r |> flatten_from_union_type()]) |> Enum.flat_map(fn x -> x end)
      _ -> [type]
    end
  end

  defp unflatten_to_union_type(types) when is_list(types) do
    case types do
      [type_hd | []] -> type_hd
      [type_hd | rest] -> {:union, {type_hd, rest |> unflatten_to_union_type()}}
    end
  end
end
